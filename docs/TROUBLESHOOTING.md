# 故障排查

## QEMU 启动失败
- 查看 logs/qemu.log
- 确认磁盘 `server.qcow2` 存在
- 以 sudo 启动（vmnet 需要权限）

## SSH 不可达
- QEMU 控制台内执行：
  - `systemctl enable --now sshd`（基于 systemd）
  - 或安装服务：`apt/yum install openssh-server`
- 宿主测试：`nc -z 127.0.0.1 2222`

## Wi‑Fi 桥接不通
- 检查 AP 是否开启“客户端隔离”（Client Isolation/AP Isolation）
  - 同一 Wi‑Fi 下两设备互 ping 不通即可能开启
  - 解决：关闭隔离或改用 USB 有线网卡
- 更换路由器或热点测试

## 网段冲突
- 脚本仅提示不自动切换
- 选择 B 切换到 192.168.201.0/24，或手动指定 `--cidr`

## Windows 网卡未配置成功
- 确认 Parallels Tools 已安装
- 以管理员运行 `C:\\Users\\Public\\Config-BizNIC.ps1`
- 查看 `Get-NetAdapter`，确认选中的是 Bridged 网卡
- 防火墙放通 ICMP 与业务端口

## 镜像转换失败
- VMDK 快照链不完整
- OVF/OVA 内引用的 vmdk 名称不匹配
- 查看 logs/convert.log 定位错误行

## 仍有问题
- 附上日志目录 logs/ 与 report.md，提交 Issue
