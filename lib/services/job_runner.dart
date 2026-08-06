import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../models/app_settings.dart';
import '../models/document_job.dart';
import 'mineru_api.dart';
import 'pdf_splitter.dart';
import 'result_merger.dart';
import 'token_vault.dart';

typedef JobUpdate = Future<void> Function(DocumentJob job);

class JobRunner {
  JobRunner({
    MinerUApi? api,
    PdfSplitter? splitter,
    ResultMerger? merger,
  })  : _api = api ?? MinerUApi(),
        _splitter = splitter ?? PdfSplitter(),
        _merger = merger ?? ResultMerger();

  final MinerUApi _api;
  final PdfSplitter _splitter;
  final ResultMerger _merger;
  final Set<String> _cancelled = {};
  final Set<String> _running = {};

  bool isRunning(String jobId) => _running.contains(jobId);

  void cancel(String jobId) => _cancelled.add(jobId);

  Future<void> run({
    required DocumentJob initialJob,
    required AppSettings settings,
    required List<MinerUToken> tokens,
    required JobUpdate onUpdate,
  }) async {
    if (_running.contains(initialJob.id)) return;
    if (tokens.isEmpty) throw StateError('请先在设置中添加 MinerU API Token');
    _running.add(initialJob.id);
    _cancelled.remove(initialJob.id);
    final session = _JobSession(initialJob, onUpdate);

    try {
      var job = session.current.copyWith(status: JobStatus.preparing, clearError: true);
      job = job.withLog('开始处理');
      await session.replace(job);

      if (session.current.chunks.isEmpty) {
        final chunksDirectory = Directory(p.join(job.workspacePath, 'chunks'));
        final split = await _splitter.prepare(
          source: File(job.sourcePath),
          chunksDirectory: chunksDirectory,
          maxPages: settings.maxPagesPerChunk,
          maxMiB: settings.maxChunkMiB,
        );
        job = session.current.copyWith(
          totalPages: split.totalPages,
          chunks: split.chunks,
        );
        job = job.withLog(
          split.chunks.length == 1
              ? '无需拆分，准备上传'
              : '已拆分为 ${split.chunks.length} 个分片',
        );
        await session.replace(job);
      }

      _throwIfCancelled(job.id);
      await _runPool(
        count: session.current.chunks.length,
        concurrency: math.max(1, math.min(settings.concurrency, 4)),
        worker: (index) => _processChunk(
          session: session,
          chunkIndex: index,
          settings: settings,
          tokens: tokens,
        ),
      );

      _throwIfCancelled(job.id);
      await session.replace(
        session.current.copyWith(status: JobStatus.merging).withLog('正在合并结果'),
      );
      final merged = await _merger.merge(job: session.current, settings: settings);
      await session.replace(
        session.current
            .copyWith(
              status: JobStatus.completed,
              outputDirectory: merged.outputDirectory,
              packageZipPath: merged.packageZipPath,
              clearError: true,
            )
            .withLog('处理完成'),
      );
    } on _JobCancelled {
      await session.replace(
        session.current.copyWith(status: JobStatus.cancelled).withLog('任务已取消'),
      );
    } on Object catch (error) {
      await session.replace(
        session.current
            .copyWith(status: JobStatus.failed, error: error.toString())
            .withLog('失败：$error'),
      );
      rethrow;
    } finally {
      _running.remove(initialJob.id);
      _cancelled.remove(initialJob.id);
    }
  }

  Future<void> _processChunk({
    required _JobSession session,
    required int chunkIndex,
    required AppSettings settings,
    required List<MinerUToken> tokens,
  }) async {
    var chunk = session.current.chunks[chunkIndex];
    if (chunk.status == ChunkStatus.completed &&
        chunk.extractedPath != null &&
        Directory(chunk.extractedPath!).existsSync()) {
      return;
    }

    var tokenIndex = chunk.tokenIndex ?? (chunk.index % tokens.length);
    if (chunk.status == ChunkStatus.uploading && chunk.batchId != null) {
      await session.updateChunk(
        chunkIndex,
        chunk.copyWith(
          status: ChunkStatus.pending,
          clearBatch: true,
          clearResult: true,
          progress: 0,
          error: '上次上传未确认完成，已重新申请上传地址',
        ),
      );
    }
    var attempts = 0;
    var waitingFilePolls = 0;
    while (true) {
      _throwIfCancelled(session.current.id);
      chunk = session.current.chunks[chunkIndex];
      final token = tokens[tokenIndex % tokens.length];
      try {
        if (chunk.batchId == null) {
          waitingFilePolls = 0;
          await session.updateChunk(
            chunkIndex,
            chunk.copyWith(
              status: ChunkStatus.uploading,
              tokenIndex: tokenIndex,
              progress: 0,
              clearError: true,
              clearResult: true,
            ),
            jobStatus: JobStatus.uploading,
          );
          final ticket = await _api.requestUpload(
            token: token.value,
            fileName: p.basename(chunk.path),
            dataId: '${session.current.id}_${chunk.index + 1}',
            settings: settings,
          );
          await session.updateChunk(
            chunkIndex,
            session.current.chunks[chunkIndex].copyWith(batchId: ticket.batchId),
          );
          await _api.uploadFile(
            uploadUrl: ticket.uploadUrl,
            file: File(chunk.path),
            onProgress: (progress) {
              unawaited(
                session.updateChunk(
                  chunkIndex,
                  session.current.chunks[chunkIndex].copyWith(
                    status: ChunkStatus.uploading,
                    progress: progress,
                  ),
                  jobStatus: JobStatus.uploading,
                ),
              );
            },
          );
          await session.updateChunk(
            chunkIndex,
            session.current.chunks[chunkIndex].copyWith(
              status: ChunkStatus.waiting,
              progress: 0,
            ),
            jobStatus: JobStatus.parsing,
          );
        }

        BatchResult result;
        while (true) {
          _throwIfCancelled(session.current.id);
          chunk = session.current.chunks[chunkIndex];
          result = await _api.getBatchResult(
            token: token.value,
            batchId: chunk.batchId!,
            fileName: p.basename(chunk.path),
          );
          if (result.state == 'waiting-file') {
            waitingFilePolls++;
            if (waitingFilePolls >= 6) {
              throw const MinerUApiException(
                '上传完成状态长时间未被 MinerU 确认',
                retryable: true,
              );
            }
          } else {
            waitingFilePolls = 0;
          }
          if (result.state == 'failed') {
            throw MinerUApiException(
              result.error?.isNotEmpty == true ? result.error! : 'MinerU 解析失败',
              retryable: false,
            );
          }
          if (result.state == 'done') break;
          await session.updateChunk(
            chunkIndex,
            chunk.copyWith(
              status: result.state == 'running'
                  ? ChunkStatus.parsing
                  : ChunkStatus.waiting,
              progress: result.progress,
            ),
            jobStatus: JobStatus.parsing,
          );
          await Future<void>.delayed(const Duration(seconds: 5));
        }

        if (result.zipUrl == null || result.zipUrl!.isEmpty) {
          throw const MinerUApiException('解析完成但没有结果下载地址', retryable: true);
        }
        final resultsDirectory = Directory(p.join(session.current.workspacePath, 'results'));
        await resultsDirectory.create(recursive: true);
        final zipPath = p.join(
          resultsDirectory.path,
          'chunk-${(chunk.index + 1).toString().padLeft(3, '0')}.zip',
        );
        await session.updateChunk(
          chunkIndex,
          session.current.chunks[chunkIndex].copyWith(
            status: ChunkStatus.downloading,
            progress: 0,
          ),
          jobStatus: JobStatus.downloading,
        );
        await _api.downloadResult(
          url: result.zipUrl!,
          destination: zipPath,
          onProgress: (progress) {
            unawaited(
              session.updateChunk(
                chunkIndex,
                session.current.chunks[chunkIndex].copyWith(
                  status: ChunkStatus.downloading,
                  progress: progress,
                ),
                jobStatus: JobStatus.downloading,
              ),
            );
          },
        );
        final extractedPath = p.join(
          resultsDirectory.path,
          'chunk-${(chunk.index + 1).toString().padLeft(3, '0')}',
        );
        await _merger.extractZip(zipPath: zipPath, destination: extractedPath);
        await session.updateChunk(
          chunkIndex,
          session.current.chunks[chunkIndex].copyWith(
            status: ChunkStatus.completed,
            progress: 1,
            resultZipPath: zipPath,
            extractedPath: extractedPath,
            clearError: true,
          ),
        );
        return;
      } on MinerUApiException catch (error) {
        attempts++;
        final current = session.current.chunks[chunkIndex];
        if (error.rotateToken && tokens.length > 1) {
          tokenIndex = (tokenIndex + 1) % tokens.length;
          await session.updateChunk(
            chunkIndex,
            current.copyWith(
              status: ChunkStatus.pending,
              clearBatch: true,
              clearResult: true,
              tokenIndex: tokenIndex,
              error: '${error.message}，切换到 ${tokens[tokenIndex].label}',
              retryCount: current.retryCount + 1,
            ),
          );
          continue;
        }
        if (error.retryable && attempts <= 4) {
          final uploadWasIncomplete = current.status == ChunkStatus.uploading ||
              error.message.contains('上传完成状态长时间未被 MinerU 确认');
          await session.updateChunk(
            chunkIndex,
            current.copyWith(
              status: ChunkStatus.pending,
              clearBatch: uploadWasIncomplete,
              clearResult: uploadWasIncomplete,
              error: '${error.message}，准备重试',
              retryCount: current.retryCount + 1,
            ),
          );
          await Future<void>.delayed(Duration(seconds: math.min(30, 1 << attempts)));
          continue;
        }
        await session.updateChunk(
          chunkIndex,
          current.copyWith(status: ChunkStatus.failed, error: error.message),
        );
        rethrow;
      } on Object catch (error) {
        attempts++;
        final current = session.current.chunks[chunkIndex];
        if (attempts <= 2) {
          final uploadWasIncomplete = current.status == ChunkStatus.uploading;
          await session.updateChunk(
            chunkIndex,
            current.copyWith(
              status: ChunkStatus.pending,
              clearBatch: uploadWasIncomplete,
              clearResult: uploadWasIncomplete,
              error: '$error，准备重试',
              retryCount: current.retryCount + 1,
            ),
          );
          await Future<void>.delayed(Duration(seconds: 2 * attempts));
          continue;
        }
        await session.updateChunk(
          chunkIndex,
          current.copyWith(status: ChunkStatus.failed, error: error.toString()),
        );
        rethrow;
      }
    }
  }

  Future<void> _runPool({
    required int count,
    required int concurrency,
    required Future<void> Function(int index) worker,
  }) async {
    var next = 0;
    Future<void> consume() async {
      while (true) {
        final index = next;
        next++;
        if (index >= count) return;
        await worker(index);
      }
    }

    await Future.wait(List.generate(math.min(count, concurrency), (_) => consume()));
  }

  void _throwIfCancelled(String jobId) {
    if (_cancelled.contains(jobId)) throw const _JobCancelled();
  }
}

class _JobSession {
  _JobSession(this.current, this._onUpdate);

  DocumentJob current;
  final JobUpdate _onUpdate;
  Future<void> _writeChain = Future.value();

  Future<void> replace(DocumentJob job) {
    current = job;
    final snapshot = job;
    _writeChain = _writeChain.then((_) => _onUpdate(snapshot));
    return _writeChain;
  }

  Future<void> updateChunk(
    int index,
    DocumentChunk chunk, {
    JobStatus? jobStatus,
  }) {
    final chunks = [...current.chunks];
    chunks[index] = chunk;
    current = current.copyWith(chunks: chunks, status: jobStatus ?? current.status);
    final snapshot = current;
    _writeChain = _writeChain.then((_) => _onUpdate(snapshot));
    return _writeChain;
  }
}

class _JobCancelled implements Exception {
  const _JobCancelled();
}
