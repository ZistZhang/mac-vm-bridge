# Mac VM Bridge

在仅有 Wi‑Fi 的 macOS 上，一键桥接 QEMU 服务端与 Parallels Windows 客户端。自动完成依赖安装、镜像转换、网络编排与健康检查。

- ✅ Wi‑Fi 默认桥接（多语言识别）
- ✅ 镜像扫描范围限定在仓库目录（支持拖拽）
- ✅ 默认 IP：服务端 192.168.200.131，Windows 192.168.200.2（冲突只提示不自动切换）
- ✅ 使用凭据自动配置服务端业务口（无网关）
- ✅ Parallels Tools 引导安装；已安装则自动在 Windows 内执行修复
- ✅ 自动检测 Windows 虚机名（无需输入）
- ✅ 兼容启动开关：MVB_COMPAT=1（IDE+e1000，适配 VMware 来宾）
- ✅ 断点续跑、日志与报告

## 快速开始
```bash
git clone https://github.com/ZistZhang/mac-vm-bridge.git
cd mac-vm-bridge
chmod +x bin/mvb scripts/*.sh
./bin/mvb                 # 首次运行；按向导选择镜像
# 老镜像（VMware）若遇到引导问题，可使用兼容模式：
MVB_COMPAT=1 DISK=$PWD/server.qcow2 ./scripts/macos/qemu-up.sh
```

- Windows 虚机无需输入名称，脚本会自动检测（优先已运行的 Windows）
- 如 Windows 未安装 Parallels Tools，会提示手动安装；已安装则自动执行 `windows/Config-BizNIC.ps1`
- 向导结束将生成 `report.md`

## 专家模式示例
```bash
./bin/mvb --cidr 192.168.201 --server-ip 192.168.201.131 --win-ip 192.168.201.2
./bin/mvb --bridge en1    # 指定桥接接口
./bin/mvb --skip-conflict-check
```

## 清理
```bash
./scripts/cleanup.sh        # 停止 QEMU，保留 qcow2 和日志
./scripts/cleanup.sh --full # 彻底清理（含 qcow2/state/logs）
```

## 许可证
MIT
