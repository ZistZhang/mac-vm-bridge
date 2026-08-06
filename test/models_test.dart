import 'package:flutter_test/flutter_test.dart';
import 'package:mineru_flow/models/app_settings.dart';
import 'package:mineru_flow/models/document_job.dart';
import 'package:mineru_flow/utils/file_utils.dart';

void main() {
  test('settings round-trip preserves parsing options', () {
    const settings = AppSettings(
      modelVersion: 'vlm',
      language: 'ch',
      enableOcr: true,
      enableFormula: false,
      maxPagesPerChunk: 160,
      maxChunkMiB: 170,
      concurrency: 3,
    );
    expect(AppSettings.fromJson(settings.toJson()).toJson(), settings.toJson());
  });

  test('job round-trip and weighted progress are deterministic', () {
    final now = DateTime.utc(2026, 8, 7);
    final job = DocumentJob(
      id: 'job',
      sourcePath: '/tmp/source.pdf',
      originalName: 'source.pdf',
      workspacePath: '/tmp/job',
      createdAt: now,
      updatedAt: now,
      status: JobStatus.parsing,
      chunks: const [
        DocumentChunk(
          index: 0,
          path: '/tmp/chunk-1.pdf',
          startPage: 1,
          endPage: 180,
          sizeBytes: 100,
          status: ChunkStatus.completed,
          progress: 1,
        ),
        DocumentChunk(
          index: 1,
          path: '/tmp/chunk-2.pdf',
          startPage: 181,
          endPage: 300,
          sizeBytes: 80,
          status: ChunkStatus.parsing,
          progress: 0.5,
        ),
      ],
    );
    final restored = DocumentJob.fromJson(job.toJson());
    expect(restored.chunks.length, 2);
    expect(restored.completedChunks, 1);
    expect(restored.progress, closeTo(job.progress, 0.0001));
  });

  test('safeStem removes unsafe separators without losing unicode', () {
    expect(safeStem('量子力学:*?.pdf'), '量子力学');
  });
}
