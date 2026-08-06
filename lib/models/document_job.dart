enum JobStatus {
  queued,
  preparing,
  uploading,
  parsing,
  downloading,
  merging,
  completed,
  paused,
  failed,
  cancelled,
}

enum ChunkStatus {
  pending,
  uploading,
  waiting,
  parsing,
  downloading,
  completed,
  failed,
}

class DocumentChunk {
  const DocumentChunk({
    required this.index,
    required this.path,
    required this.startPage,
    required this.endPage,
    required this.sizeBytes,
    this.status = ChunkStatus.pending,
    this.batchId,
    this.tokenIndex,
    this.progress = 0,
    this.resultZipPath,
    this.extractedPath,
    this.error,
    this.retryCount = 0,
  });

  final int index;
  final String path;
  final int startPage;
  final int endPage;
  final int sizeBytes;
  final ChunkStatus status;
  final String? batchId;
  final int? tokenIndex;
  final double progress;
  final String? resultZipPath;
  final String? extractedPath;
  final String? error;
  final int retryCount;

  int get pageCount => endPage - startPage + 1;

  DocumentChunk copyWith({
    ChunkStatus? status,
    String? batchId,
    bool clearBatch = false,
    int? tokenIndex,
    double? progress,
    String? resultZipPath,
    String? extractedPath,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    int? retryCount,
  }) {
    return DocumentChunk(
      index: index,
      path: path,
      startPage: startPage,
      endPage: endPage,
      sizeBytes: sizeBytes,
      status: status ?? this.status,
      batchId: clearBatch ? null : (batchId ?? this.batchId),
      tokenIndex: tokenIndex ?? this.tokenIndex,
      progress: progress ?? this.progress,
      resultZipPath: clearResult ? null : (resultZipPath ?? this.resultZipPath),
      extractedPath: clearResult ? null : (extractedPath ?? this.extractedPath),
      error: clearError ? null : (error ?? this.error),
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, Object?> toJson() => {
        'index': index,
        'path': path,
        'startPage': startPage,
        'endPage': endPage,
        'sizeBytes': sizeBytes,
        'status': status.name,
        'batchId': batchId,
        'tokenIndex': tokenIndex,
        'progress': progress,
        'resultZipPath': resultZipPath,
        'extractedPath': extractedPath,
        'error': error,
        'retryCount': retryCount,
      };

  factory DocumentChunk.fromJson(Map<String, Object?> json) => DocumentChunk(
        index: json['index'] as int,
        path: json['path'] as String,
        startPage: json['startPage'] as int,
        endPage: json['endPage'] as int,
        sizeBytes: json['sizeBytes'] as int,
        status: ChunkStatus.values.byName(
          json['status'] as String? ?? ChunkStatus.pending.name,
        ),
        batchId: json['batchId'] as String?,
        tokenIndex: json['tokenIndex'] as int?,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        resultZipPath: json['resultZipPath'] as String?,
        extractedPath: json['extractedPath'] as String?,
        error: json['error'] as String?,
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

class DocumentJob {
  const DocumentJob({
    required this.id,
    required this.sourcePath,
    required this.originalName,
    required this.workspacePath,
    required this.createdAt,
    required this.updatedAt,
    this.status = JobStatus.queued,
    this.totalPages,
    this.chunks = const [],
    this.outputDirectory,
    this.packageZipPath,
    this.error,
    this.log = const [],
  });

  final String id;
  final String sourcePath;
  final String originalName;
  final String workspacePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final JobStatus status;
  final int? totalPages;
  final List<DocumentChunk> chunks;
  final String? outputDirectory;
  final String? packageZipPath;
  final String? error;
  final List<String> log;

  double get progress {
    if (status == JobStatus.completed) return 1;
    if (chunks.isEmpty) {
      return switch (status) {
        JobStatus.queued => 0,
        JobStatus.preparing => 0.06,
        JobStatus.failed => 0,
        _ => 0.02,
      };
    }
    final chunkProgress = chunks.fold<double>(0, (sum, chunk) {
      return sum + switch (chunk.status) {
        ChunkStatus.pending => 0,
        ChunkStatus.uploading => 0.15 + chunk.progress * 0.2,
        ChunkStatus.waiting => 0.4,
        ChunkStatus.parsing => 0.4 + chunk.progress * 0.35,
        ChunkStatus.downloading => 0.78 + chunk.progress * 0.17,
        ChunkStatus.completed => 1,
        ChunkStatus.failed => 0,
      };
    });
    final base = chunkProgress / chunks.length;
    if (status == JobStatus.merging) return 0.96;
    return base * 0.94;
  }

  int get completedChunks =>
      chunks.where((chunk) => chunk.status == ChunkStatus.completed).length;

  DocumentJob copyWith({
    JobStatus? status,
    int? totalPages,
    List<DocumentChunk>? chunks,
    String? outputDirectory,
    String? packageZipPath,
    bool clearOutput = false,
    String? error,
    bool clearError = false,
    List<String>? log,
  }) {
    return DocumentJob(
      id: id,
      sourcePath: sourcePath,
      originalName: originalName,
      workspacePath: workspacePath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      status: status ?? this.status,
      totalPages: totalPages ?? this.totalPages,
      chunks: chunks ?? this.chunks,
      outputDirectory: clearOutput ? null : (outputDirectory ?? this.outputDirectory),
      packageZipPath: clearOutput ? null : (packageZipPath ?? this.packageZipPath),
      error: clearError ? null : (error ?? this.error),
      log: log ?? this.log,
    );
  }

  DocumentJob withLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    return copyWith(log: [...log, '$timestamp  $message']);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'sourcePath': sourcePath,
        'originalName': originalName,
        'workspacePath': workspacePath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'totalPages': totalPages,
        'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
        'outputDirectory': outputDirectory,
        'packageZipPath': packageZipPath,
        'error': error,
        'log': log,
      };

  factory DocumentJob.fromJson(Map<String, Object?> json) => DocumentJob(
        id: json['id'] as String,
        sourcePath: json['sourcePath'] as String,
        originalName: json['originalName'] as String,
        workspacePath: json['workspacePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: JobStatus.values.byName(
          json['status'] as String? ?? JobStatus.queued.name,
        ),
        totalPages: json['totalPages'] as int?,
        chunks: (json['chunks'] as List<Object?>? ?? const [])
            .map(
              (item) => DocumentChunk.fromJson(
                Map<String, Object?>.from(item! as Map),
              ),
            )
            .toList(),
        outputDirectory: json['outputDirectory'] as String?,
        packageZipPath: json['packageZipPath'] as String?,
        error: json['error'] as String?,
        log: (json['log'] as List<Object?>? ?? const []).cast<String>(),
      );
}
