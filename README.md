# MinerU Flow

MinerU Flow is a local-first Windows, macOS and Android client for converting documents to Markdown through the MinerU API.

It is designed for the common workflow of receiving a large PDF, converting it quickly, and sending the resulting Markdown to an AI agent without manually splitting, uploading, downloading, or merging anything.

## Features

- Windows, macOS and Android from one Flutter codebase.
- Local files are split on the device before upload.
- PDF chunks are kept below both 180 pages and 180 MiB by default.
- MinerU v4 local-upload API integration.
- Multiple user-supplied API tokens with failover.
- Resumable jobs: app restarts continue from saved batch IDs and downloaded chunks.
- Bounded concurrency and exponential retry.
- Automatic ZIP extraction, Markdown merge, image renaming and path rewriting.
- Produces `document.md`, `README_FOR_AGENT.md`, `manifest.json`, assets, raw chunk outputs and a shareable ZIP.
- Android share-intent import.
- Tokens are stored in the platform secure credential store.
- No server, telemetry, account-password automation, or bundled MinerU credentials.

## Build locally

Install Flutter 3.44.7 or newer, then:

```bash
flutter create --platforms=android,windows,macos .
python3 scripts/prepare_platforms.py
flutter pub get
flutter pub run flutter_launcher_icons
flutter test
```

Build targets:

```bash
flutter build apk --release
flutter build windows --release
flutter build macos --release
```

A Windows build must run on Windows; a macOS build must run on macOS.

## API setup

Create a token in the MinerU API management page and add it in **Settings → API tokens**. MinerU Flow never stores account passwords. It only stores tokens entered by the user.

## Output layout

```text
export/
├── <document-name>/
│   ├── document.md
│   ├── README_FOR_AGENT.md
│   ├── manifest.json
│   ├── assets/
│   └── raw-chunks/
└── <document-name>-agent-package.zip
```

## Security and privacy

Document chunks are uploaded directly from the device to MinerU's signed upload URL. No project-owned relay server is involved. API tokens are stored with Keychain on macOS, the Windows credential implementation supplied by `flutter_secure_storage`, and encrypted Android storage.

## Attribution

The long-PDF workflow was informed by the MIT-licensed community project `neosun100/mineru-mcp-server`. This project reimplements the workflow in Dart/Flutter and does not include that project's account-login automation.

## License

MIT
