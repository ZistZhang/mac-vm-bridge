import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

String safeFileName(String fileName) {
  final safe = p.basename(fileName)
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]+'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return safe.isEmpty ? 'file' : safe;
}

String safeStem(String fileName) {
  final stem = p
      .basenameWithoutExtension(safeFileName(fileName))
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return stem.isEmpty ? 'document' : stem;
}

String humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KiB';
  final mib = kib / 1024;
  if (mib < 1024) return '${mib.toStringAsFixed(1)} MiB';
  return '${(mib / 1024).toStringAsFixed(2)} GiB';
}

Future<String> sha256File(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

Future<void> copyFileAtomic(File source, File destination) async {
  await destination.parent.create(recursive: true);
  final temporary = File('${destination.path}.partial');
  if (await temporary.exists()) await temporary.delete();
  await source.openRead().pipe(temporary.openWrite());
  if (await destination.exists()) await destination.delete();
  await temporary.rename(destination.path);
}

Future<File?> findFileNamed(Directory root, String name) async {
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && p.basename(entity.path) == name) return entity;
  }
  return null;
}

String uniquePath(String desiredPath) {
  final desired = File(desiredPath);
  if (!desired.existsSync() && !Directory(desiredPath).existsSync()) {
    return desiredPath;
  }
  final directory = p.dirname(desiredPath);
  final extension = p.extension(desiredPath);
  final stem = p.basenameWithoutExtension(desiredPath);
  var counter = 2;
  while (true) {
    final candidate = p.join(directory, '$stem-$counter$extension');
    if (!File(candidate).existsSync() && !Directory(candidate).existsSync()) {
      return candidate;
    }
    counter++;
  }
}
