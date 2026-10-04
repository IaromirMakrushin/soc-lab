#Requires -RunAsAdministrator
#
# 08-Remove-WazuhTempNIC.ps1
# Removes WAZUH01's temporary internet NIC so the SIEM is back to LAB-Isolated
# only, then takes the 05-wazuh-installed checkpoint. Run on the host.
#

$Name = "WAZUH01"

if ((Get-VM -Name $Name).State -ne "Off") {
    Write-Host "Shutting down $Name..."
    Stop-VM -Name $Name
}

Get-VMNetworkAdapter -VMName $Name | Where-Object Name -eq "TEMP-Internet" |
    Remove-VMNetworkAdapter

$nics = Get-VMNetworkAdapter -VMName $Name
$nics | Select-Object Name, SwitchName, MacAddress
if ($nics | Where-Object SwitchName -ne "LAB-Isolated") {
    Write-Error "$Name still has a NIC outside LAB-Isolated!"; exit 1
}

Checkpoint-VM -Name $Name -SnapshotName "05-wazuh-installed"
Write-Host "$Name is isolated again; checkpoint 05-wazuh-installed taken." -ForegroundColor Green
