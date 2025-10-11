# TROUBLESHOOTING

- Windows ping 失败/“常见故障”：检查 SkipAsSource 是否为 False；业务网卡无默认网关；必要时添加 /32 主机路由。
- Wi‑Fi 桥接不通：AP 可能启用 Client Isolation；改用 USB 有线网卡或 PD Default Adapter；确保 QEMU 与 PD 桥到同一物理口。
- QEMU 无 vmnet-bridged：升级 QEMU；或改用 USB 网卡；临时只能 NAT（不满足业务直连）。
- 来宾无 sshd 或无凭据：用控制台执行 3 条命令卡片（启用 sshd、配置静态 IP、开放端口），再重试。
