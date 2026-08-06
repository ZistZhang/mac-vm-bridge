import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/document_job.dart';

class JobStore {
  File? _file;

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
    if (!await file.exists()) return [];
    try {
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
    } on Object {
      final backup = File('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(backup.path);
      return [];
    }
  }

  Future<void> save(List<DocumentJob> jobs) async {
    final file = await _resolveFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final encoder = const JsonEncoder.withIndent('  ');
    await temporary.writeAsString(
      encoder.convert(jobs.map((job) => job.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<void> deleteWorkspace(DocumentJob job) async {
    final dir = Directory(job.workspacePath);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
