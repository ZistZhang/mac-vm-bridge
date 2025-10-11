# Mac VM Bridge

一键把 QEMU（x86_64 服务端）与 Parallels Windows 客户端在仅 Wi‑Fi 的 macOS 上桥接互通：
- 默认业务网段 192.168.200.0/24；服务端 192.168.200.131（QEMU）、客户端 192.168.200.2（Parallels）
- 仅提示网段冲突，不擅自切换；两端业务网卡均不配默认网关
- 支持 OVA/OVF/VMX/VMDK → qcow2 转换；NAT 管理口 127.0.0.1:2222 → :22
- Windows 侧 SkipAsSource 一键修复（需已安装 Parallels Tools），或提供手工执行脚本

法律与使用边界：仅用于本地局域网学习与实验；不分发任何第三方镜像/数据；不提供公网部署指导。详见 LEGAL.md。

## 快速开始

1) 依赖检查（QEMU + vmnet、Parallels CLI）
```
./scripts/macos/check-vmnet.sh
```
2) 转换镜像（示例：指定 vmdk/ova/ovf/vmx 之一）
```
python3 tools/vm2qemu/vm2qemu.py convert --src /path/to/disk.vmdk --out ./server --name server.qcow2
```
3) 启动服务端（NAT 管理 + Wi‑Fi 桥接业务）
```
BR_IF=en0 DISK=./server/server.qcow2 ./scripts/macos/qemu-up.sh
```
4) 配置 Windows（添加 Shared+Bridged 网卡，修复业务 IP）
```
./scripts/macos/pd-add-bridged.sh "WinClient" en0
# Windows 内安装 Parallels Tools 后：
# 将 windows/Config-BizNIC.ps1 拷贝到 VM 中执行，或使用 prlctl exec 调用
```
5) 健康检查
- 从宿主：`ssh -p 2222 127.0.0.1`；
- QEMU 来宾 ping `192.168.200.2`；Windows ping `192.168.200.131`。

更多细节见 docs/QUICKSTART.md 与 docs/TROUBLESHOOTING.md。

## 目录结构
- scripts/macos: QEMU 启停、vmnet 检测、PD 网卡配置
- scripts/windows: Windows 侧网络修复与诊断脚本
- tools/vm2qemu: 镜像探测/转换/运行工具（原型）
- docs: 快速开始、排错、合规说明

## 许可证
- 代码：Apache-2.0
- 文档：CC BY 4.0
