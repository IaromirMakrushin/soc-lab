#Requires -RunAsAdministrator
#
# 10-Copy-Installers.ps1
# Copies Sysmon, its config, the Wazuh agent MSI and 09-Install-Sysmon-WazuhAgent.ps1
# from the host into DC01 and WIN11-01 (C:\Lab\Installers) via Hyper-V Guest Services.
# The lab has no internet, so this is how software gets in. Run on the host.
#

$VMs  = "DC01", "WIN11-01"
$Src  = "C:\Lab\Installers"
$Dest = "C:\Lab\Installers"
$Files = @(
    "Sysmon\Sysmon64.exe",
    "Sysmon\Eula.txt",
    "sysmonconfig-export.xml",
    "wazuh-agent-4.14.8-1.msi"
)

foreach ($vm in $VMs) {
    Enable-VMIntegrationService -VMName $vm -Name "Guest Service Interface"
    Start-Sleep 5
    $items = @($Files | ForEach-Object { @{ From = Join-Path $Src $_; To = Join-Path $Dest $_ } })
    $items += @{ From = "$PSScriptRoot\09-Install-Sysmon-WazuhAgent.ps1"; To = "$Dest\09-Install-Sysmon-WazuhAgent.ps1" }
    foreach ($it in $items) {
        $done = $false
        for ($i = 1; $i -le 6 -and -not $done; $i++) {
            try {
                Copy-VMFile -Name $vm -FileSource Host -CreateFullPath -Force `
                            -SourcePath $it.From -DestinationPath $it.To -ErrorAction Stop
                $done = $true
            } catch { Start-Sleep 5 }
        }
        if ($done) { Write-Host "[$vm] $($it.To)" -ForegroundColor Green }
        else       { Write-Host "[$vm] FAILED $($it.To)" -ForegroundColor Red }
    }
}
