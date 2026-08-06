class AppSettings {
  const AppSettings({
    this.modelVersion = 'vlm',
    this.language = 'ch',
    this.enableOcr = false,
    this.enableFormula = true,
    this.enableTable = true,
    this.maxPagesPerChunk = 180,
    this.maxChunkMiB = 180,
    this.concurrency = 2,
    this.keepRawChunks = true,
    this.autoStart = true,
  });

  final String modelVersion;
  final String language;
  final bool enableOcr;
  final bool enableFormula;
  final bool enableTable;
  final int maxPagesPerChunk;
  final int maxChunkMiB;
  final int concurrency;
  final bool keepRawChunks;
  final bool autoStart;

  AppSettings copyWith({
    String? modelVersion,
    String? language,
    bool? enableOcr,
    bool? enableFormula,
    bool? enableTable,
    int? maxPagesPerChunk,
    int? maxChunkMiB,
    int? concurrency,
    bool? keepRawChunks,
    bool? autoStart,
  }) {
    return AppSettings(
      modelVersion: modelVersion ?? this.modelVersion,
      language: language ?? this.language,
      enableOcr: enableOcr ?? this.enableOcr,
      enableFormula: enableFormula ?? this.enableFormula,
      enableTable: enableTable ?? this.enableTable,
      maxPagesPerChunk: maxPagesPerChunk ?? this.maxPagesPerChunk,
      maxChunkMiB: maxChunkMiB ?? this.maxChunkMiB,
      concurrency: concurrency ?? this.concurrency,
      keepRawChunks: keepRawChunks ?? this.keepRawChunks,
      autoStart: autoStart ?? this.autoStart,
    );
  }

  Map<String, Object?> toJson() => {
        'modelVersion': modelVersion,
        'language': language,
        'enableOcr': enableOcr,
        'enableFormula': enableFormula,
        'enableTable': enableTable,
        'maxPagesPerChunk': maxPagesPerChunk,
        'maxChunkMiB': maxChunkMiB,
        'concurrency': concurrency,
        'keepRawChunks': keepRawChunks,
        'autoStart': autoStart,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        modelVersion: json['modelVersion'] as String? ?? 'vlm',
        language: json['language'] as String? ?? 'ch',
        enableOcr: json['enableOcr'] as bool? ?? false,
        enableFormula: json['enableFormula'] as bool? ?? true,
        enableTable: json['enableTable'] as bool? ?? true,
        maxPagesPerChunk: json['maxPagesPerChunk'] as int? ?? 180,
        maxChunkMiB: json['maxChunkMiB'] as int? ?? 180,
        concurrency: json['concurrency'] as int? ?? 2,
        keepRawChunks: json['keepRawChunks'] as bool? ?? true,
        autoStart: json['autoStart'] as bool? ?? true,
      );
}
