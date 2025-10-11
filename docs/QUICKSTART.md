# QUICKSTART

- 依赖检查：`scripts/macos/check-vmnet.sh`
- 转换镜像：`python3 tools/vm2qemu/vm2qemu.py convert --src <ova|ovf|vmdk|vmx> --out ./server --name server.qcow2`
- 启动 QEMU：`BR_IF=en0 DISK=./server/server.qcow2 scripts/macos/qemu-up.sh`
- PD 网卡：`scripts/macos/pd-add-bridged.sh "WinClient" en0`
- Windows 修复：在来宾内运行 `scripts/windows/Config-BizNIC.ps1`
- 验证：互 ping；如失败，见 TROUBLESHOOTING.md
