#Requires -RunAsAdministrator
#
# 06-Create-WazuhVM.ps1
# Creates the WAZUH01 SIEM VM (Ubuntu Server 24.04) on the isolated lab switch.
# Run as Administrator on the host.
#
# The Wazuh installer downloads packages from the internet, but LAB-Isolated has
# none. Pass -TempInternet to add a SECOND, temporary NIC on Hyper-V's NAT
# "Default Switch" for the install. Remove it afterwards with
# 08-Remove-WazuhTempNIC.ps1, before any attack traffic exists in the lab.
#
#   .\06-Create-WazuhVM.ps1 -TempInternet
#

param([switch]$TempInternet)

$Name    = "WAZUH01"
$Switch  = "LAB-Isolated"
$VHDPath = "C:\Lab\VHDs\WAZUH01.vhdx"
$ISO     = "C:\Lab\ISO\ubuntu-24.04.4-live-server-amd64.iso"

# Fixed MACs (00:15:5D = Hyper-V prefix) so netplan in the guest can match the
# right NIC regardless of eth0/eth1 ordering. 07-Wazuh-Setup.sh uses the same values.
$LabMac  = "00155D0A0A14"
$TempMac = "00155D0A0AF0"

if (-not (Get-VMSwitch -Name $Switch -ErrorAction SilentlyContinue)) {
    Write-Error "Switch '$Switch' not found."; exit 1
}
if (-not (Test-Path $ISO)) {
    Write-Error "ISO not found at $ISO"; exit 1
}
if ($TempInternet -and -not (Get-VMSwitch -Name "Default Switch" -ErrorAction SilentlyContinue)) {
    Write-Error "'Default Switch' not found; cannot add temporary internet NIC."; exit 1
}

# Create VM + 100 GB dynamic disk (indexer data grows)
# 6 GB: enough for a 2-agent lab; 8 GB would not start alongside DC01 + WIN11-01 on a 32 GB host
New-VM -Generation 2 -Name $Name -MemoryStartupBytes 6144MB `
       -NewVHDPath $VHDPath -NewVHDSizeBytes 100GB -SwitchName $Switch

# Wazuh indexer (OpenSearch/JVM) misbehaves with dynamic memory -> fixed size
Set-VMMemory    -VMName $Name -DynamicMemoryEnabled $false
Set-VMProcessor -VMName $Name -Count 4
Set-VM          -VMName $Name -AutomaticCheckpointsEnabled $false

# Linux Gen-2 guest: Secure Boot off (lab convention)
Set-VMFirmware -VMName $Name -EnableSecureBoot Off

# Lab NIC with fixed MAC
Get-VMNetworkAdapter -VMName $Name | Set-VMNetworkAdapter -StaticMacAddress $LabMac
Rename-VMNetworkAdapter -VMName $Name -Name "Network Adapter" -NewName "LAB"

# Optional temporary internet NIC
if ($TempInternet) {
    Add-VMNetworkAdapter -VMName $Name -Name "TEMP-Internet" -SwitchName "Default Switch" `
                         -StaticMacAddress $TempMac
}

Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"

# Attach the install ISO and boot from it first
Add-VMDvdDrive -VMName $Name -Path $ISO
$dvd = Get-VMDvdDrive -VMName $Name
Set-VMFirmware -VMName $Name -FirstBootDevice $dvd

Write-Host ""
Write-Host "WAZUH01 created, booting the Ubuntu ISO." -ForegroundColor Green
Get-VM -Name $Name | Select-Object Name, State, ProcessorCount, @{n='MemGB';e={$_.MemoryStartup/1GB}}
Get-VMNetworkAdapter -VMName $Name | Select-Object Name, SwitchName, MacAddress
Get-VMFirmware -VMName $Name | Select-Object SecureBoot
