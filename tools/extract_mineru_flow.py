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

print(f'Extracted {len(parts)} parts into {destination.resolve()}')
