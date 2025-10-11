# 快速开始

1. 克隆与授权
```bash
git clone https://github.com/ZistZhang/mac-vm-bridge.git
cd mac-vm-bridge
chmod +x bin/mvb scripts/*.sh
```

2. 运行入口（自动检测 Windows 虚机名）
```bash
./bin/mvb
```
- 选择或拖拽镜像（支持 OVA/OVF/VMX 或含 VMX 的目录）
- 确认默认 IP：服务端 192.168.200.131，Windows 192.168.200.2（冲突只提示）
- 如 Windows 未装 Parallels Tools，按提示安装后继续

3. 兼容模式（遇到 dracut/驱动问题时使用）
```bash
MVB_COMPAT=1 DISK=$PWD/server.qcow2 ./scripts/macos/qemu-up.sh
```

4. 健康检查
- 向导会生成 `report.md`，包含连通性结果与日志路径

5. 清理
```bash
./scripts/cleanup.sh        # 停止 QEMU，保留 qcow2 和日志
./scripts/cleanup.sh --full # 彻底清理
```
