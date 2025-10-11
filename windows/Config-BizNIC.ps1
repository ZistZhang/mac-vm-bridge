param(
  [string]$ServerIP = "192.168.200.131",
  [string]$WindowsIP = "192.168.200.2",
  [int]$Prefix = 24
)

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
  Write-Warning "请以管理员身份运行 PowerShell（Run as administrator）。"
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Windows 业务网卡配置" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "目标配置:"
Write-Host "  IP 地址: $WindowsIP/$Prefix"
Write-Host "  默认网关: (无)"
Write-Host "  DNS: (无)"
Write-Host "  服务端 IP: $ServerIP"
Write-Host ""

# 1) 识别 Parallels Bridged 网卡
Write-Host "[1/4] 识别 Parallels Bridged 网卡..." -ForegroundColor Yellow
$nic = Get-NetAdapter |
  Where-Object {
    $_.Status -eq "Up" -and (
      $_.InterfaceDescription -like "*Parallels*Bridged*" -or
      ($_.InterfaceDescription -like "*Parallels*" -and $_.InterfaceDescription -notlike "*Shared*")
    )
  } |
  Sort-Object ifIndex |
  Select-Object -First 1

if (-not $nic) {
  Write-Error "未找到合适的 Parallels Bridged 网卡。"
  Get-NetAdapter | Format-Table Name, Status, InterfaceDescription -AutoSize
  exit 1
}

$ifAlias = $nic.InterfaceAlias
$ifIdx = $nic.ifIndex
Write-Host "  ✓ 网卡: $ifAlias" -ForegroundColor Green
Write-Host "    描述: $($nic.InterfaceDescription)" -ForegroundColor Gray
Write-Host ""

# 2) 清理既有 IPv4 配置
Write-Host "[2/4] 清理既有 IPv4 配置..." -ForegroundColor Yellow
try { Set-NetIPInterface -InterfaceAlias $ifAlias -Dhcp Disabled -AddressFamily IPv4 -ErrorAction SilentlyContinue | Out-Null } catch {}
Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.PrefixOrigin -ne "WellKnown" } |
  ForEach-Object {
    Write-Host "  移除旧 IP: $($_.IPAddress)" -ForegroundColor Gray
    Remove-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $_.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
  }
Get-NetRoute -InterfaceAlias $ifAlias -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
  ForEach-Object {
    Write-Host "  移除默认网关" -ForegroundColor Gray
    Remove-NetRoute -InterfaceAlias $ifAlias -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
  }
try { Set-DnsClientServerAddress -InterfaceAlias $ifAlias -ResetServerAddresses -ErrorAction SilentlyContinue } catch {}
Write-Host "  ✓ 清理完成" -ForegroundColor Green
Write-Host ""

# 3) 配置静态 IP
Write-Host "[3/4] 配置静态 IP..." -ForegroundColor Yellow
$setOk = $false
try {
  New-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $WindowsIP -PrefixLength $Prefix -AddressFamily IPv4 -ErrorAction Stop | Out-Null
  $setOk = $true
} catch {
  Write-Host "  ⚠ 新建失败，尝试修改..." -ForegroundColor Yellow
  try {
    $cur = Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction Stop | Select-Object -First 1
    if ($cur) {
      Set-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $WindowsIP -PrefixLength $Prefix -ErrorAction Stop | Out-Null
      $setOk = $true
    }
  } catch {
    Write-Host "  ⚠ 修改失败，尝试重建..." -ForegroundColor Yellow
    try {
      Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
      New-NetIPAddress -InterfaceAlias $ifAlias -IPAddress $WindowsIP -PrefixLength $Prefix -AddressFamily IPv4 -ErrorAction Stop | Out-Null
      $setOk = $true
    } catch {
      Write-Error "设置 IP 失败：$($_.Exception.Message)"; exit 1
    }
  }
}
if ($setOk) {
  Write-Host "  ✓ 已设置 IP: $WindowsIP/$Prefix" -ForegroundColor Green
}
try {
  Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $WindowsIP } |
    Set-NetIPAddress -SkipAsSource $false -ErrorAction SilentlyContinue
} catch {}
Write-Host ""

# 4) 状态与诊断
Write-Host "[4/4] 当前状态" -ForegroundColor Yellow
Get-NetIPAddress -InterfaceAlias $ifAlias -AddressFamily IPv4 | Format-Table IPAddress,PrefixLength,InterfaceAlias,SkipAsSource -AutoSize
Write-Host ""
route print -4
Write-Host ""
Write-Host "完成。该业务网卡未配置默认网关，不影响默认上网路径。" -ForegroundColor Green
