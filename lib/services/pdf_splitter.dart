import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/io.dart' as pdf_io;
import 'package:pdf_manipulator/pdf_manipulator.dart';

import '../models/document_job.dart';

class SplitResult {
  const SplitResult({required this.totalPages, required this.chunks});

  final int? totalPages;
  final List<DocumentChunk> chunks;
}

class PdfSplitter {
  Future<SplitResult> prepare({
    required File source,
    required Directory chunksDirectory,
    required int maxPages,
    required int maxMiB,
  }) async {
    if (await chunksDirectory.exists()) {
      await chunksDirectory.delete(recursive: true);
    }
    await chunksDirectory.create(recursive: true);
    if (p.extension(source.path).toLowerCase() != '.pdf') {
      return SplitResult(
        totalPages: null,
        chunks: [
          DocumentChunk(
            index: 0,
            path: source.path,
            startPage: 1,
            endPage: 1,
            sizeBytes: await source.length(),
          ),
        ],
      );
    }

    final engine = Pdf();
    try {
      final document = await engine.open(pdf_io.FileSource(source));
      final totalPages = document.pageCount;
      await document.dispose();
      if (totalPages < 1) throw StateError('PDF 不包含可解析页面');

      final maxBytes = maxMiB * 1024 * 1024;
      final pieces = <_Piece>[];
      if (totalPages <= maxPages && await source.length() <= maxBytes) {
        pieces.add(
          _Piece(
            file: source,
            startPage: 1,
            endPage: totalPages,
          ),
        );
      } else {
        final count = (totalPages / maxPages).ceil();
        final sinks = <pdf_io.FileSink>[];
        final outputFiles = <File>[];
        try {
          for (var index = 0; index < count; index++) {
            final file = File(
              p.join(
                chunksDirectory.path,
                'stage-${(index + 1).toString().padLeft(3, '0')}.pdf',
              ),
            );
            outputFiles.add(file);
            sinks.add(await pdf_io.FileSink.create(file));
          }
          await engine.split(
            pdf_io.FileSource(source),
            (index) => sinks[index],
            every: maxPages,
          );
        } finally {
          for (final sink in sinks) {
            await sink.close();
          }
        }

        for (var index = 0; index < outputFiles.length; index++) {
          final start = index * maxPages + 1;
          final end = math.min(totalPages, start + maxPages - 1);
          pieces.add(
            _Piece(file: outputFiles[index], startPage: start, endPage: end),
          );
        }
      }

      final sizeSafePieces = <_Piece>[];
      for (final piece in pieces) {
        sizeSafePieces.addAll(
          await _ensureSizeLimit(
            engine: engine,
            piece: piece,
            chunksDirectory: chunksDirectory,
            maxBytes: maxBytes,
          ),
        );
      }
      sizeSafePieces.sort((a, b) => a.startPage.compareTo(b.startPage));

      final chunks = <DocumentChunk>[];
      for (var index = 0; index < sizeSafePieces.length; index++) {
        final piece = sizeSafePieces[index];
        final canonical = File(
          p.join(
            chunksDirectory.path,
            'chunk-${(index + 1).toString().padLeft(3, '0')}.pdf',
          ),
        );
        File finalFile = piece.file;
        if (p.normalize(piece.file.path) != p.normalize(canonical.path)) {
          if (await canonical.exists()) await canonical.delete();
          final inside = p.isWithin(chunksDirectory.path, piece.file.path);
          finalFile = inside
              ? await piece.file.rename(canonical.path)
              : await piece.file.copy(canonical.path);
        }
        chunks.add(
          DocumentChunk(
            index: index,
            path: finalFile.path,
            startPage: piece.startPage,
            endPage: piece.endPage,
            sizeBytes: await finalFile.length(),
          ),
        );
      }
      return SplitResult(totalPages: totalPages, chunks: chunks);
    } finally {
      await engine.dispose();
    }
  }

  Future<List<_Piece>> _ensureSizeLimit({
    required Pdf engine,
    required _Piece piece,
    required Directory chunksDirectory,
    required int maxBytes,
  }) async {
    if (await piece.file.length() <= maxBytes) return [piece];

    final doc = await engine.open(pdf_io.FileSource(piece.file));
    final pageCount = doc.pageCount;
    await doc.dispose();
    if (pageCount <= 1) {
      throw StateError(
        '原始第 ${piece.startPage} 页单页超过 ${(maxBytes / 1024 / 1024).round()} MiB，无法满足 MinerU 上传限制',
      );
    }

    final leftCount = pageCount ~/ 2;
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final left = File(p.join(chunksDirectory.path, 'split-$nonce-left.pdf'));
    final right = File(p.join(chunksDirectory.path, 'split-$nonce-right.pdf'));
    final leftSink = await pdf_io.FileSink.create(left);
    final rightSink = await pdf_io.FileSink.create(right);
    try {
      await engine.extractPages(
        pdf_io.FileSource(piece.file),
        leftSink,
        pages: List.generate(leftCount, (index) => index),
      );
      await engine.extractPages(
        pdf_io.FileSource(piece.file),
        rightSink,
        pages: List.generate(pageCount - leftCount, (index) => leftCount + index),
      );
    } finally {
      await leftSink.close();
      await rightSink.close();
    }

    final sourceInsideChunkDirectory =
        p.isWithin(chunksDirectory.path, piece.file.path);
    if (sourceInsideChunkDirectory && await piece.file.exists()) {
      await piece.file.delete();
    }

    final leftPiece = _Piece(
      file: left,
      startPage: piece.startPage,
      endPage: piece.startPage + leftCount - 1,
    );
    final rightPiece = _Piece(
      file: right,
      startPage: leftPiece.endPage + 1,
      endPage: piece.endPage,
    );
    return [
      ...await _ensureSizeLimit(
        engine: engine,
        piece: leftPiece,
        chunksDirectory: chunksDirectory,
        maxBytes: maxBytes,
      ),
      ...await _ensureSizeLimit(
        engine: engine,
        piece: rightPiece,
        chunksDirectory: chunksDirectory,
        maxBytes: maxBytes,
      ),
    ];
  }
}

class _Piece {
  const _Piece({
    required this.file,
    required this.startPage,
    required this.endPage,
  });

  final File file;
  final int startPage;
  final int endPage;
}
