import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/document_job.dart';
import '../services/job_runner.dart';
import '../services/job_store.dart';
import '../services/token_vault.dart';
import '../utils/file_utils.dart';

class AppController extends ChangeNotifier {
  AppController({
    JobStore? store,
    TokenVault? vault,
    JobRunner? runner,
  })  : _store = store ?? JobStore(),
        _vault = vault ?? TokenVault(),
        _runner = runner ?? JobRunner();

  static const _settingsKey = 'mineru_flow_settings_v1';
  final JobStore _store;
  final TokenVault _vault;
  final JobRunner _runner;
  final Uuid _uuid = const Uuid();

  List<DocumentJob> _jobs = [];
  List<MinerUToken> _tokens = [];
  AppSettings _settings = const AppSettings();
  bool _initializing = true;
  bool _importing = false;
  String? _message;
  int _navigationIndex = 0;

  List<DocumentJob> get jobs => List.unmodifiable(_jobs);
  List<MinerUToken> get tokens => List.unmodifiable(_tokens);
  AppSettings get settings => _settings;
  bool get initializing => _initializing;
  bool get importing => _importing;
  String? get message => _message;
  int get navigationIndex => _navigationIndex;
  int get runningCount => _jobs.where((job) => _runner.isRunning(job.id)).length;

  void setNavigationIndex(int value) {
    if (_navigationIndex == value) return;
    _navigationIndex = value;
    notifyListeners();
  }

  void clearMessage() {
    _message = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawSettings = prefs.getString(_settingsKey);
      if (rawSettings != null) {
        _settings = AppSettings.fromJson(
          Map<String, Object?>.from(jsonDecode(rawSettings) as Map),
        );
      }
      _tokens = await _vault.readAll();
      _jobs = await _store.load();
      _jobs = _jobs.map((job) {
        if ({
          JobStatus.preparing,
          JobStatus.uploading,
          JobStatus.parsing,
          JobStatus.downloading,
          JobStatus.merging,
        }.contains(job.status)) {
          return job.copyWith(status: JobStatus.paused).withLog('应用重启，任务可继续');
        }
        return job;
      }).toList();
      await _persistJobs();
    } catch (error) {
      _message = '初始化失败：$error';
    } finally {
      _initializing = false;
      notifyListeners();
    }

    if (_settings.autoStart && _tokens.isNotEmpty) {
      for (final job in _jobs.where(
        (job) => job.status == JobStatus.queued || job.status == JobStatus.paused,
      )) {
        unawaited(startJob(job.id));
      }
    }
  }

  Future<void> importPaths(List<String> paths) async {
    final valid = paths
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && File(value).existsSync())
        .toSet()
        .toList();
    if (valid.isEmpty) {
      _message = '没有可读取的文件';
      notifyListeners();
      return;
    }
    _importing = true;
    _message = null;
    notifyListeners();

    final root = await _store.applicationRoot();
    final created = <DocumentJob>[];
    try {
      for (final sourcePath in valid) {
        final source = File(sourcePath);
        final id = _uuid.v4();
        final workspace = Directory(p.join(root.path, 'jobs', id));
        final input = Directory(p.join(workspace.path, 'input'));
        await input.create(recursive: true);
        final originalName = p.basename(source.path);
        final localPath = p.join(input.path, 'source${p.extension(originalName)}');
        await copyFileAtomic(source, File(localPath));
        final now = DateTime.now();
        created.add(
          DocumentJob(
            id: id,
            sourcePath: localPath,
            originalName: originalName,
            workspacePath: workspace.path,
            createdAt: now,
            updatedAt: now,
          ).withLog('文件已导入'),
        );
      }
      _jobs = [...created.reversed, ..._jobs];
      await _persistJobs();
      _navigationIndex = 1;
      _message = '已导入 ${created.length} 个文件';
    } catch (error) {
      _message = '导入失败：$error';
    } finally {
      _importing = false;
      notifyListeners();
    }

    if (_settings.autoStart && _tokens.isNotEmpty) {
      for (final job in created) {
        unawaited(startJob(job.id));
      }
    }
  }

  Future<void> startJob(String id) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    if (index < 0 || _runner.isRunning(id)) return;
    _tokens = await _vault.readAll();
    if (_tokens.isEmpty) {
      _message = '请先在设置中添加 MinerU API Token';
      _navigationIndex = 2;
      notifyListeners();
      return;
    }
    final job = _jobs[index].status == JobStatus.completed
        ? _resetCompletedJob(_jobs[index])
        : _jobs[index].copyWith(clearError: true);
    _jobs[index] = job;
    await _persistJobs();
    notifyListeners();

    try {
      await _runner.run(
        initialJob: job,
        settings: _settings,
        tokens: _tokens,
        onUpdate: (updated) async {
          final currentIndex = _jobs.indexWhere((item) => item.id == updated.id);
          if (currentIndex < 0) return;
          _jobs[currentIndex] = updated;
          _jobs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          await _persistJobs();
          notifyListeners();
        },
      );
    } on Object {
      // The runner persists the detailed failure on the job.
    }
  }

  DocumentJob _resetCompletedJob(DocumentJob job) {
    final resetChunks = job.chunks
        .map(
          (chunk) => chunk.copyWith(
            status: ChunkStatus.pending,
            clearBatch: true,
            clearResult: true,
            clearError: true,
            progress: 0,
          ),
        )
        .toList();
    return job.copyWith(
      status: JobStatus.queued,
      chunks: resetChunks,
      clearOutput: true,
      clearError: true,
    );
  }

  Future<void> retryJob(String id) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    if (index < 0) return;
    final job = _jobs[index];
    final chunks = job.chunks
        .map(
          (chunk) => chunk.status == ChunkStatus.failed
              ? chunk.copyWith(
                  status: ChunkStatus.pending,
                  clearBatch: true,
                  clearResult: true,
                  clearError: true,
                  progress: 0,
                )
              : chunk,
        )
        .toList();
    _jobs[index] = job.copyWith(
      status: JobStatus.queued,
      chunks: chunks,
      clearError: true,
    );
    await _persistJobs();
    notifyListeners();
    await startJob(id);
  }

  Future<void> cancelJob(String id) async {
    _runner.cancel(id);
    final index = _jobs.indexWhere((job) => job.id == id);
    if (index >= 0 && !_runner.isRunning(id)) {
      _jobs[index] = _jobs[index].copyWith(status: JobStatus.cancelled);
      await _persistJobs();
      notifyListeners();
    }
  }

  Future<void> deleteJob(String id) async {
    final index = _jobs.indexWhere((job) => job.id == id);
    if (index < 0) return;
    _runner.cancel(id);
    final job = _jobs.removeAt(index);
    await _persistJobs();
    notifyListeners();
    try {
      await _store.deleteWorkspace(job);
    } on Object {
      // Keep history deletion successful even when the OS retains a file handle.
    }
  }

  Future<void> updateSettings(AppSettings value) async {
    _settings = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(value.toJson()));
    notifyListeners();
  }

  Future<void> addToken(String label, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final actualLabel = label.trim().isEmpty ? 'Token ${_tokens.length + 1}' : label.trim();
    _tokens = [..._tokens, MinerUToken(label: actualLabel, value: trimmed)];
    await _vault.writeAll(_tokens);
    _message = 'Token 已安全保存';
    notifyListeners();
  }

  Future<void> removeToken(int index) async {
    if (index < 0 || index >= _tokens.length) return;
    final updated = [..._tokens]..removeAt(index);
    _tokens = updated;
    await _vault.writeAll(updated);
    notifyListeners();
  }

  Future<void> _persistJobs() => _store.save(_jobs);
}
