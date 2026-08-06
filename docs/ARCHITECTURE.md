# Architecture

MinerU Flow is a local-first Flutter application. Windows, macOS, and Android share the same task engine and MinerU API adapter.

## Processing pipeline

1. Copy the selected source into an application-owned workspace.
2. Inspect PDF page count and real byte size.
3. Split at the configured page threshold. Any output still over the byte threshold is recursively bisected.
4. Request one MinerU V4 batch upload ticket per chunk.
5. Upload, persist the batch ID, poll, download, and safely extract each result.
6. Merge `full.md` files in original page order; deduplicate asset names and rewrite local image references.
7. Generate `document.md`, `manifest.json`, `README_FOR_AGENT.md`, and an Agent-ready ZIP.

Every material transition is written to disk. Restarted applications convert interrupted jobs to `paused` and resume from the latest persisted batch ID instead of resubmitting completed work.

## Security boundaries

- API tokens are stored with `flutter_secure_storage` and are never written to job manifests or logs.
- Source documents and API results remain under the local application support directory.
- ZIP extraction rejects absolute and parent-traversal paths.
- Token rotation occurs only after authentication/rate-limit errors; a submitted chunk remains bound to its token for polling.
- The application never automates MinerU account login or CAPTCHA handling.
