# 快速开始

1. 克隆与授权
```bash
git clone https://github.com/your-org/mac-vm-bridge.git
cd mac-vm-bridge
chmod +x bin/mvb scripts/*.sh
```

2. 运行入口
```bash
./bin/mvb
```

3. 按向导提示
- 选择或拖拽镜像（支持 OVA/OVF/VMX 或含 VMX 的目录）
- 确认默认 IP：服务端 192.168.200.131，Windows 192.168.200.2
- 输入服务端凭据（默认 root/123456）
- 如 Windows 未安装 Parallels Tools，按提示安装并继续

4. 健康检查
- 脚本会生成 report.md，包含连通性结果和日志路径

5. 清理
```bash
./scripts/cleanup.sh        # 停止 QEMU，保留 qcow2 和日志
./scripts/cleanup.sh --full # 彻底清理
```
