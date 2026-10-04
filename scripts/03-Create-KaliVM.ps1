#Requires -RunAsAdministrator
#
# 03-Create-KaliVM.ps1
# Creates the KALI01 attacker VM from the pre-built Kali Hyper-V disk,
# placed on the ISOLATED lab switch (LAB-Isolated) so attack traffic never
# leaves the lab. Adapted from Kali's shipped create-vm.ps1.
# Run as Administrator on the host.
#

$Name     = "KALI01"
$Switch   = "LAB-Isolated"
$VHDPath  = "C:\Lab\VMs\kali-linux-2026.2-hyperv-amd64\kali-linux-2026.2-hyperv-amd64.vhdx"

# Safety check: the isolated switch must already exist (created in Step 1).
if (-not (Get-VMSwitch -Name $Switch -ErrorAction SilentlyContinue)) {
    Write-Error "Switch '$Switch' not found. Create it before running this."
    exit 1
}

New-VM -Generation 2 -Name $Name -MemoryStartupBytes 2048MB `
       -SwitchName $Switch -VHDPath $VHDPath

# Resources
Set-VMMemory   -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes 1024MB -MaximumBytes 4096MB
Set-VMProcessor -VMName $Name -Count 2

# Linux Gen-2 guests need Secure Boot OFF
Set-VMFirmware -VMName $Name -EnableSecureBoot Off

# Keep the lab tidy: no automatic checkpoints
Set-VM -Name $Name -AutomaticCheckpointsEnabled $false

# Helpful integration service
Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"

Write-Host ""
Write-Host "KALI01 created on $Switch (isolated). Login: kali / kali" -ForegroundColor Green
Get-VM -Name $Name | Select-Object Name, State, @{n='Switch';e={($_ | Get-VMNetworkAdapter).SwitchName}}, ProcessorCount
