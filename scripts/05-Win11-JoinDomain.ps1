#Requires -RunAsAdministrator
#
# 05-Win11-JoinDomain.ps1
# Run INSIDE WIN11-01 (elevated PowerShell) after Windows 11 is installed and
# you are logged in with the local admin account.
# Sets static IP 10.10.10.101 (DNS -> DC01), renames the PC and joins lab.internal.
# The machine reboots at the end.
#
# Copy it into the VM by pasting it into PowerShell ISE / Notepad, or from the host
# (Enhanced Session lets you paste files).
#

$NewName = "WIN11-01"
$IP      = "10.10.10.101"
$Prefix  = 24
$DNS     = "10.10.10.10"
$Domain  = "lab.internal"

# Pick the single connected adapter (name differs on Swedish Windows)
$nic = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1
if (-not $nic) { Write-Error "No connected network adapter found."; exit 1 }

# Static IP (no gateway: the lab switch is isolated)
Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
New-NetIPAddress   -InterfaceIndex $nic.ifIndex -IPAddress $IP -PrefixLength $Prefix | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $DNS

# Sanity check: DC must resolve before we try to join. A freshly set IP is
# "tentative" for a few seconds, so retry instead of failing immediately.
$resolved = $false
for ($i = 1; $i -le 12 -and -not $resolved; $i++) {
    Clear-DnsClientCache
    if (Resolve-DnsName $Domain -DnsOnly -ErrorAction SilentlyContinue) { $resolved = $true }
    else { Write-Host "Waiting for DNS ($i/12)..."; Start-Sleep 5 }
}
if (-not $resolved) {
    Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 | Select-Object IPAddress, AddressState
    Test-Connection $DNS -Count 2
    Write-Error "Cannot resolve $Domain via $DNS. Is DC01 running?"; exit 1
}
Write-Host "DNS OK - $Domain resolves." -ForegroundColor Green

# Rename + join in one step (prompts for LAB\Administrator credentials)
$cred = Get-Credential -Message "Domain admin, e.g. LAB\Administrator"
Add-Computer -DomainName $Domain -NewName $NewName -Credential $cred -Restart -Force
