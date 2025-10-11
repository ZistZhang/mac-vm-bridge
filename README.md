# Mac VM Bridge

在仅有 Wi‑Fi 的 macOS 上，一键桥接 QEMU 服务端与 Parallels Windows 客户端。自动完成依赖安装、镜像转换、网络编排与健康检查。

- ✅ Wi‑Fi 默认桥接（多语言识别）
- ✅ 镜像扫描范围限定在仓库目录（支持拖拽）
- ✅ 默认 IP：服务端 192.168.200.131，Windows 192.168.200.2
- ✅ 冲突只提示不自动切换（可选切换 201 网段）
- ✅ 使用凭据自动配置服务端业务口（无网关）
- ✅ Parallels Tools 引导安装并自动配置 Windows
- ✅ 断点续跑、日志与报告
- ✅ 一键清理

## 快速开始
```bash
git clone https://github.com/your-org/mac-vm-bridge.git
cd mac-vm-bridge
chmod +x bin/mvb scripts/*.sh
./bin/mvb
```

- 选择或拖拽镜像（OVA/OVF/VMX 或含 VMX 的目录）
- 输入（或接受默认）IP：服务端 200.131，Windows 200.2
- 输入服务端凭据（默认 root/123456）
- Windows 侧按提示安装 Parallels Tools（如未安装）
- 结束后查看 report.md

更多细节见 docs/QUICKSTART.md

## 专家模式
```bash
./bin/mvb --cidr 192.168.201 --server-ip 192.168.201.131 --win-ip 192.168.201.2
./bin/mvb --bridge en1
./bin/mvb --vm "Windows 11"
./bin/mvb --skip-conflict-check
./bin/mvb --help
```

## 清理
```bash
./scripts/cleanup.sh        # 停止 QEMU，清理临时文件
./scripts/cleanup.sh --full # 额外删除 qcow2、日志、状态
```

## 要求
- macOS 13+（Apple Silicon 测试通过）
- Parallels Desktop 18+（含 prlctl）
- 磁盘 ≥20GB（镜像转换）
- 默认 Wi‑Fi 桥接（建议关闭 AP 客户端隔离）

## 架构
见 docs/ARCHITECTURE.md

## 许可证
MIT
