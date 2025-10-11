Write-Host "诊断开始..." -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 | ft IPAddress,InterfaceAlias,SkipAsSource -AutoSize
route print -4

Write-Host "测试与 192.168.200.131 的连通..." -ForegroundColor Cyan
ping 192.168.200.131 -n 3

Write-Host "若失败：1) 确认 SkipAsSource=false；2) 业务网卡无默认网关；3) 可添加 /32 主机路由；4) 排除 AP 客户端隔离。"
