# 贡献指南

1. Fork → 新分支 → 提交 → PR
2. Shell 脚本通过 ShellCheck（CI 会检查）
3. 提交信息遵循 Conventional Commits（feat/fix/docs/chore...）
4. 重要变更需同步文档

本地检查：
```bash
shellcheck scripts/*.sh bin/mvb
```
