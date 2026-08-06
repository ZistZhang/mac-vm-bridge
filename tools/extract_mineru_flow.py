#!/usr/bin/env python3
"""Extract and patch the temporary MinerU Flow source bundle for CI."""
from __future__ import annotations

import base64
import shutil
import tarfile
from pathlib import Path

bundle_dir = Path('bundle/mineru-flow-bootstrap')
destination = Path('project')
parts = sorted(bundle_dir.glob('source.part-*'))
if not parts:
    raise SystemExit(f'No MinerU Flow source parts under {bundle_dir}')

encoded = ''.join(part.read_text(encoding='utf-8') for part in parts)
archive_path = Path('mineru-flow-source.tar.xz')
archive_path.write_bytes(base64.b64decode(encoded))

if destination.exists():
    shutil.rmtree(destination)
destination.mkdir(parents=True)
with tarfile.open(archive_path, mode='r:xz') as archive:
    archive.extractall(destination)

splitter = destination / 'lib/services/pdf_splitter.dart'
text = splitter.read_text(encoding='utf-8')
text = text.replace(
    "import 'package:pdf_manipulator/io.dart';",
    "import 'package:pdf_manipulator/io.dart' as pdf_io;",
)
text = text.replace('FileSource(', 'pdf_io.FileSource(')
text = text.replace('<FileSink>[]', '<pdf_io.FileSink>[]')
text = text.replace('FileSink.create(', 'pdf_io.FileSink.create(')
splitter.write_text(text, encoding='utf-8')

job_store = destination / 'lib/services/job_store.dart'
job_store.write_text(r'''import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_job.dart';

class JobStore {
  File? _file;
  Future<void> _writeTail = Future<void>.value();

  Future<Directory> applicationRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory(p.join(support.path, 'MinerUFlow'));
    await root.create(recursive: true);
    return root;
  }

  Future<File> _resolveFile() async {
    if (_file != null) return _file!;
    final root = await applicationRoot();
    _file = File(p.join(root.path, 'jobs.json'));
    return _file!;
  }

  Future<List<DocumentJob>> load() async {
    final file = await _resolveFile();
    final backup = File('${file.path}.bak');
    if (!await file.exists() && await backup.exists()) {
      await backup.copy(file.path);
    }
    if (!await file.exists()) return [];
    try {
      return await _decode(file);
    } on Object {
      if (await backup.exists()) {
        try {
          final recovered = await _decode(backup);
          await backup.copy(file.path);
          return recovered;
        } on Object {
          // Preserve both broken files below for manual inspection.
        }
      }
      final corrupt = File(
        '${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}',
      );
      await file.copy(corrupt.path);
      return [];
    }
  }

  Future<List<DocumentJob>> _decode(File file) async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return [];
    final decoded = jsonDecode(raw) as List<Object?>;
    return decoded
        .map(
          (item) => DocumentJob.fromJson(
            Map<String, Object?>.from(item! as Map),
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(List<DocumentJob> jobs) {
    final encoder = const JsonEncoder.withIndent('  ');
    final payload = encoder.convert(jobs.map((job) => job.toJson()).toList());
    final operation = _writeTail.then((_) => _write(payload));
    _writeTail = operation.then<void>((_) {}, onError: (_, __) {});
    return operation;
  }

  Future<void> _write(String payload) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(payload, flush: true);

    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } on Object {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }

  Future<void> deleteWorkspace(DocumentJob job) async {
    final dir = Directory(job.workspacePath);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
''', encoding='utf-8')

print(f'Extracted {len(parts)} parts into {destination.resolve()}')
