import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/app_settings.dart';

class MinerUApiException implements Exception {
  const MinerUApiException(
    this.message, {
    this.code,
    this.retryable = false,
    this.rotateToken = false,
  });

  final String message;
  final Object? code;
  final bool retryable;
  final bool rotateToken;

  @override
  String toString() => message;
}

class UploadTicket {
  const UploadTicket({required this.batchId, required this.uploadUrl});

  final String batchId;
  final String uploadUrl;
}

class BatchResult {
  const BatchResult({
    required this.state,
    this.zipUrl,
    this.error,
    this.extractedPages,
    this.totalPages,
  });

  final String state;
  final String? zipUrl;
  final String? error;
  final int? extractedPages;
  final int? totalPages;

  double get progress {
    if (state == 'done') return 1;
    if (totalPages == null || totalPages == 0 || extractedPages == null) {
      return state == 'running' ? 0.35 : 0.05;
    }
    return (extractedPages! / totalPages!).clamp(0, 1);
  }
}

class MinerUApi {
  MinerUApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://mineru.net',
                connectTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(minutes: 20),
                receiveTimeout: const Duration(minutes: 5),
                validateStatus: (status) => status != null && status < 500,
              ),
            );

  final Dio _dio;

  Options _authorized(String token) => Options(
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer ${token.trim()}',
          HttpHeaders.acceptHeader: 'application/json',
        },
      );

  Future<UploadTicket> requestUpload({
    required String token,
    required String fileName,
    required String dataId,
    required AppSettings settings,
  }) async {
    try {
      final isHtml = fileName.toLowerCase().endsWith('.html') ||
          fileName.toLowerCase().endsWith('.htm');
      final data = <String, Object?>{
        'files': [
          {
            'name': fileName,
            'data_id': dataId,
            if (!isHtml) 'is_ocr': settings.enableOcr,
          },
        ],
        'model_version': isHtml ? 'MinerU-HTML' : settings.modelVersion,
        if (!isHtml) 'language': settings.language,
        if (!isHtml) 'enable_formula': settings.enableFormula,
        if (!isHtml) 'enable_table': settings.enableTable,
      };
      final response = await _dio.post<Map<String, Object?>>(
        '/api/v4/file-urls/batch',
        options: _authorized(token),
        data: data,
      );
      final body = _bodyOrThrow(response);
      final responseData = Map<String, Object?>.from(body['data']! as Map);
      final urls = (responseData['file_urls'] as List<Object?>?)?.cast<String>();
      if (urls == null || urls.isEmpty) {
        throw const MinerUApiException('MinerU 未返回上传地址', retryable: true);
      }
      return UploadTicket(
        batchId: responseData['batch_id'] as String,
        uploadUrl: urls.first,
      );
    } on DioException catch (error) {
      throw _fromDio(error, '申请上传地址失败');
    }
  }

  Future<void> uploadFile({
    required String uploadUrl,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final length = await file.length();
      final response = await _dio.put<Object?>(
        uploadUrl,
        data: file.openRead(),
        options: Options(
          headers: {HttpHeaders.contentLengthHeader: length},
          followRedirects: true,
          maxRedirects: 5,
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 3),
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );
      if ((response.statusCode ?? 500) >= 300) {
        throw MinerUApiException(
          '文件上传失败（HTTP ${response.statusCode}）',
          retryable: true,
        );
      }
    } on DioException catch (error) {
      throw _fromDio(error, '文件上传失败');
    }
  }

  Future<BatchResult> getBatchResult({
    required String token,
    required String batchId,
    required String fileName,
  }) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '/api/v4/extract-results/batch/$batchId',
        options: _authorized(token),
      );
      final body = _bodyOrThrow(response);
      final data = Map<String, Object?>.from(body['data']! as Map);
      final results = (data['extract_result'] as List<Object?>? ?? const [])
          .map((item) => Map<String, Object?>.from(item! as Map))
          .toList();
      if (results.isEmpty) {
        return const BatchResult(state: 'waiting-file');
      }
      final result = results.firstWhere(
        (item) => item['file_name'] == fileName,
        orElse: () => results.first,
      );
      final progress = result['extract_progress'] is Map
          ? Map<String, Object?>.from(result['extract_progress']! as Map)
          : null;
      return BatchResult(
        state: result['state'] as String? ?? 'pending',
        zipUrl: result['full_zip_url'] as String?,
        error: result['err_msg'] as String?,
        extractedPages: progress?['extracted_pages'] as int?,
        totalPages: progress?['total_pages'] as int?,
      );
    } on DioException catch (error) {
      throw _fromDio(error, '查询解析进度失败');
    }
  }

  Future<void> downloadResult({
    required String url,
    required String destination,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final partial = '$destination.partial';
      final partialFile = File(partial);
      if (await partialFile.exists()) await partialFile.delete();
      await _dio.download(
        url,
        partial,
        options: Options(
          receiveTimeout: const Duration(minutes: 20),
          followRedirects: true,
          validateStatus: (status) => status != null && status >= 200 && status < 300,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
      final finalFile = File(destination);
      if (await finalFile.exists()) await finalFile.delete();
      await partialFile.rename(destination);
    } on DioException catch (error) {
      throw _fromDio(error, '下载解析结果失败');
    }
  }

  Map<String, Object?> _bodyOrThrow(Response<Map<String, Object?>> response) {
    final body = response.data;
    if (body == null) {
      throw MinerUApiException(
        'MinerU 返回空响应（HTTP ${response.statusCode}）',
        retryable: true,
      );
    }
    final code = body['code'];
    if (response.statusCode == 200 && (code == 0 || code == '0')) return body;
    final message = body['msg']?.toString() ?? 'MinerU 请求失败';
    final normalized = code?.toString();
    final auth = normalized == 'A0202' || normalized == 'A0211' || response.statusCode == 401;
    const transientCodes = {
      '-10001',
      '-60001',
      '-60007',
      '-60009',
      '-60010',
      '-60020',
      '-60021',
    };
    final quota = normalized == '-60018' || normalized == '-60019';
    final retryable = response.statusCode == 429 ||
        response.statusCode == 408 ||
        transientCodes.contains(normalized);
    throw MinerUApiException(
      '$message${code == null ? '' : '（$code）'}',
      code: code,
      rotateToken: auth || quota || response.statusCode == 429,
      retryable: retryable,
    );
  }

  MinerUApiException _fromDio(DioException error, String prefix) {
    final status = error.response?.statusCode;
    final isTimeout = error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
    final rotate = status == 401 || status == 403 || status == 429;
    return MinerUApiException(
      '$prefix：${error.message ?? error.type.name}${status == null ? '' : '（HTTP $status）'}',
      code: status,
      retryable: isTimeout || status == null || status >= 500 || status == 408 || status == 429,
      rotateToken: rotate,
    );
  }
}
