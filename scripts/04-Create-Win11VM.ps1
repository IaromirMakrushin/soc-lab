#Requires -RunAsAdministrator
#
# 04-Create-Win11VM.ps1
# Creates the WIN11-01 domain-client VM on the isolated lab switch, with the
# TPM + Secure Boot that Windows 11 requires, and boots the install ISO.
# Run as Administrator on the host.
#

$Name    = "WIN11-01"
$Switch  = "LAB-Isolated"
$VHDPath = "C:\Lab\VHDs\WIN11-01.vhdx"
$ISO     = "C:\Users\makru\Downloads\Win11_25H2_Swedish_x64.iso"

if (-not (Get-VMSwitch -Name $Switch -ErrorAction SilentlyContinue)) {
    Write-Error "Switch '$Switch' not found."; exit 1
}
if (-not (Test-Path $ISO)) {
    Write-Error "ISO not found at $ISO"; exit 1
}

# Create VM + new 64 GB dynamic disk
New-VM -Generation 2 -Name $Name -MemoryStartupBytes 4096MB `
       -NewVHDPath $VHDPath -NewVHDSizeBytes 64GB -SwitchName $Switch

# Resources
Set-VMMemory    -VMName $Name -DynamicMemoryEnabled $true -MinimumBytes 1024MB -MaximumBytes 4096MB
Set-VMProcessor -VMName $Name -Count 2
Set-VM          -VMName $Name -AutomaticCheckpointsEnabled $false

# Windows 11 requirements: TPM (needs a key protector first) + Secure Boot
Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector
Enable-VMTPM       -VMName $Name
Set-VMFirmware     -VMName $Name -EnableSecureBoot On -SecureBootTemplate "MicrosoftWindows"

# Attach the install ISO and boot from it first
Add-VMDvdDrive -VMName $Name -Path $ISO
$dvd = Get-VMDvdDrive -VMName $Name
Set-VMFirmware -VMName $Name -FirstBootDevice $dvd

Write-Host ""
Write-Host "WIN11-01 created on $Switch with TPM + Secure Boot, booting the ISO." -ForegroundColor Green
Get-VM -Name $Name | Select-Object Name, State, ProcessorCount
Get-VMFirmware -VMName $Name | Select-Object SecureBoot
(Get-VMSecurity -VMName $Name) | Select-Object TpmEnabled
