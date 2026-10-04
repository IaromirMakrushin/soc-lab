#Requires -RunAsAdministrator
#
# 09-Install-Sysmon-WazuhAgent.ps1
# Run INSIDE DC01 and WIN11-01 (elevated). Installers are copied to
# C:\Lab\Installers by 10-Copy-Installers.ps1 on the host.
#
# 1. Installs Sysmon with the SwiftOnSecurity config.
# 2. Installs the Wazuh agent and enrolls it with WAZUH01 (10.10.10.20).
# 3. Adds the Sysmon + PowerShell event channels to the agent's log collection
#    (the default Windows agent config only reads Application/Security/System).
#

$Src     = "C:\Lab\Installers"
$Manager = "10.10.10.20"
$AgentMsi = Join-Path $Src "wazuh-agent-4.14.8-1.msi"
$OssecConf = "C:\Program Files (x86)\ossec-agent\ossec.conf"

foreach ($f in "$Src\Sysmon\Sysmon64.exe", "$Src\sysmonconfig-export.xml", $AgentMsi) {
    if (-not (Test-Path $f)) { Write-Error "Missing $f - run 10-Copy-Installers.ps1 on the host."; exit 1 }
}

# --- Sysmon -------------------------------------------------------------------
if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
    Write-Host "Sysmon already installed - updating config."
    & "$Src\Sysmon\Sysmon64.exe" -c "$Src\sysmonconfig-export.xml"
} else {
    & "$Src\Sysmon\Sysmon64.exe" -accepteula -i "$Src\sysmonconfig-export.xml"
}

# --- Wazuh agent --------------------------------------------------------------
if (-not (Get-Service WazuhSvc -ErrorAction SilentlyContinue)) {
    $msiArgs = "/i `"$AgentMsi`" /qn WAZUH_MANAGER=$Manager WAZUH_AGENT_NAME=$env:COMPUTERNAME"
    $p = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Error "Wazuh agent MSI failed (exit $($p.ExitCode))"; exit 1 }
}

# Extra event channels for detection work
$channels = @(
    "Microsoft-Windows-Sysmon/Operational",
    "Microsoft-Windows-PowerShell/Operational",
    "Microsoft-Windows-Windows Defender/Operational"
)
$conf = Get-Content $OssecConf -Raw
$add = ""
foreach ($c in $channels) {
    if ($conf -notmatch [regex]::Escape("<location>$c</location>")) {
        $add += "`n  <localfile>`n    <location>$c</location>`n    <log_format>eventchannel</log_format>`n  </localfile>`n"
    }
}
if ($add) {
    $i = $conf.LastIndexOf("</ossec_config>")
    $conf = $conf.Substring(0, $i) + $add + $conf.Substring($i)
    Set-Content -Path $OssecConf -Value $conf -Encoding ASCII
}

Restart-Service WazuhSvc
Start-Sleep 10

# --- Status -------------------------------------------------------------------
Get-Service Sysmon64, WazuhSvc | Select-Object Name, Status
$state = Get-Content "C:\Program Files (x86)\ossec-agent\wazuh-agent.state" -ErrorAction SilentlyContinue |
         Select-String "status"
Write-Host "Agent $state" -ForegroundColor Green
Write-Host "Expected: status='connected'. Check the Wazuh dashboard -> Agents."
