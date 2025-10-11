# Repository Guidelines

## Project Structure & Modules
- `bin/mvb`: entrypoint (bootstrap + wizard).
- `scripts/`: Bash automation (bootstrap, wizard, cleanup); legacy helpers in `scripts/macos/` and Windows prototypes in `scripts/windows/`.
- `windows/`: production PowerShell for configuring the PD bridged NIC.
- `docs/`: QUICKSTART, TROUBLESHOOTING, ARCHITECTURE; update when flows change.
- `.github/`: issue/PR templates and CI (ShellCheck).
- Runtime artifacts live outside Git: `server.qcow2`, `logs/`, `report.md`.

## Build, Test, and Dev Commands
- Run locally: `./bin/mvb` (full wizard) or `./scripts/wizard.sh`.
- Bootstrap deps: `./scripts/bootstrap.sh` (Homebrew, QEMU, jq, expect).
- Cleanup: `./scripts/cleanup.sh [--full]`.
- Lint shell: `shellcheck scripts/*.sh bin/mvb` (CI runs this).
- Example end‑to‑end: convert → start → configure → report, all via wizard.

## Coding Style & Naming
- Bash: `#!/usr/bin/env bash` + `set -euo pipefail`; 2‑space indent; kebab‑case filenames (`wizard.sh`). Prefer explicit vars (`BRIDGE_IF`, `SERVER_IP`).
- PowerShell: 2‑space indent; parameters with defaults; use `Write-Host` for user prompts; avoid destructive changes; admin checks where needed.
- Docs: concise, imperative voice; keep examples runnable.

## Testing Guidelines
- Linting is mandatory (ShellCheck). Add `# shellcheck disable=SCxxxx` only with rationale.
- Smoke test: run `./bin/mvb` against a small OVA/VMDK and verify report.md shows three green checks.
- New scripts should be idempotent and support dry‑run flags if practical.

## Commit & Pull Request Guidelines
- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`; scope optional (e.g., `feat(wizard): conflict prompt`).
- PRs must include: brief problem statement, what changed, how to verify (commands), and screenshots or `logs/*.log` snippets when relevant. Link issues.
- Never commit binaries or secrets (`*.qcow2`, `*.vmdk`, `report.md`, credentials). Respect `.gitignore`.

## Security & Configuration Tips
- LAN‑only; do not add 0.0.0.0 port forwards. Business NICs use static IP without gateway.
- Prefer Wi‑Fi `en0` bridge; document when USB NICs are required (AP client isolation).
- Keep sudo prompts minimal; specify commands and reasons in code comments.
