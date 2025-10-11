param(
  [string]$BizIP = "192.168.200.2",
  [int]$Prefix = 24,
  [string]$ServerIP = "192.168.200.131"
)

# Pick a NIC without default gateway (likely the bridged business NIC)
$nic = Get-NetIPConfiguration -AddressFamily IPv4 |
  Where-Object { $_.IPv4DefaultGateway -eq $null } |
  Select-Object -First 1

if (-not $nic) { Write-Error "未找到可用的业务网卡（无默认网关）。"; exit 1 }
$ifAlias = $nic.InterfaceAlias

# Set static IP (no gateway)
$existing = Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -like "192.168.*" }
if ($existing) {
  foreach ($e in $existing) { try { Remove-NetIPAddress -InputObject $e -Confirm:$false } catch {} }
}
New-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $BizIP -PrefixLength $Prefix -AddressFamily IPv4 -ErrorAction Stop | Out-Null

# Ensure SkipAsSource = false
Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -eq $BizIP } |
  Set-NetIPAddress -SkipAsSource $false

# Optional: add /32 host route to server IP as insurance
$ifIndex = (Get-NetAdapter -InterfaceAlias $ifAlias).ifIndex
route -p add $ServerIP mask 255.255.255.255 $BizIP IF $ifIndex METRIC 1 2>$null | Out-Null

Write-Host "配置完成：$ifAlias -> $BizIP/$Prefix (SkipAsSource=false)"
Get-NetIPAddress -AddressFamily IPv4 | ft IPAddress,InterfaceAlias,SkipAsSource -AutoSize
route print -4
