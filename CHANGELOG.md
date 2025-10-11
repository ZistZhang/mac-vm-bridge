# Changelog

## [0.1.0] - 2024-10-XX
### Added
- 自动依赖安装（Homebrew, QEMU, expect, jq 等）
- 镜像扫描与转换（OVA/OVF/VMX → qcow2）
- QEMU 启动（NAT 管理口 + Wi‑Fi 桥接业务口）
- 服务端自动配置（凭据 + expect）
- Parallels Windows 自动配置（Tools 检测与引导）
- 健康检查与 Markdown 报告
- 断点续跑与一键清理

### Fixed
- macOS find 兼容性（移除 -printf/-maxdepth）
- Wi‑Fi 多语言识别
- SSH 密码传递（expect）
- Windows 网卡选择与 IP 配置幂等

[0.1.0]: https://github.com/your-org/mac-vm-bridge/releases/tag/v0.1.0
