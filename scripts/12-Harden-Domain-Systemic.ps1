#Requires -RunAsAdministrator
#
# 12-Harden-Domain-Systemic.ps1
# Phase 5, iteration 2: systemic (domain-wide) hardening, targeting the specific
# PingCastle rules that scored points in the baseline. Run on DC01 as domain admin.
# Each block is wrapped so one failure does not stop the rest.
# After running: gpupdate /force here AND on the clients, then re-run PingCastle.
#
Import-Module ActiveDirectory
Import-Module GroupPolicy

$DDP = "Default Domain Policy"

function Try-Step($name, [scriptblock]$code) {
    Write-Host "== $name ==" -ForegroundColor Cyan
    try { & $code; Write-Host "   OK" -ForegroundColor Green }
    catch { Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red }
}

# --- Anomalies: password length < 8  (+10) -> require 14 -----------------------
Try-Step "Password policy: min length 14" {
    Set-ADDefaultDomainPasswordPolicy -Identity lab.internal `
        -MinPasswordLength 14 -PasswordHistoryCount 24 `
        -MinPasswordAge (New-TimeSpan -Days 1) -MaxPasswordAge (New-TimeSpan -Days 365)
}

# --- Stale: non-admins can add 10 computers (+10) -> quota 0 -------------------
Try-Step "ms-DS-MachineAccountQuota = 0" {
    Set-ADDomain -Identity lab.internal -Replace @{"ms-DS-MachineAccountQuota"="0"}
}

# --- Stale: subnet not declared (+5) -> declare 10.10.10.0/24 ------------------
Try-Step "Declare AD subnet 10.10.10.0/24" {
    if (-not (Get-ADReplicationSubnet -Filter "Name -eq '10.10.10.0/24'" -ErrorAction SilentlyContinue)) {
        New-ADReplicationSubnet -Name "10.10.10.0/24" -Site "Default-First-Site-Name"
    }
}

# --- Stale: service account(s) without AES (+10) -> set AES on all SPN users ---
Try-Step "Force AES on all accounts that have an SPN" {
    Get-ADUser -LDAPFilter "(servicePrincipalName=*)" -Properties msDS-SupportedEncryptionTypes |
        ForEach-Object { Set-ADUser $_ -Replace @{'msDS-SupportedEncryptionTypes'=24} }
}

# --- Stale: LM / NTLMv1 allowed (+15) -> NTLMv2 only, refuse LM & NTLM ---------
Try-Step "LAN Manager auth level = 5 (NTLMv2 only)" {
    Set-GPRegistryValue -Name $DDP -Key "HKLM\System\CurrentControlSet\Control\Lsa" `
        -ValueName "LmCompatibilityLevel" -Type DWord -Value 5 | Out-Null
}

# --- Anomalies: hardened UNC paths weakened (+5) -> require mutual auth+integrity
Try-Step "Hardened UNC paths for SYSVOL and NETLOGON" {
    $k = "HKLM\Software\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths"
    Set-GPRegistryValue -Name $DDP -Key $k -ValueName "\\*\SYSVOL" -Type String `
        -Value "RequireMutualAuthentication=1, RequireIntegrity=1" | Out-Null
    Set-GPRegistryValue -Name $DDP -Key $k -ValueName "\\*\NETLOGON" -Type String `
        -Value "RequireMutualAuthentication=1, RequireIntegrity=1" | Out-Null
}

# --- Disable RC4 domain-wide (AES + future types only) ------------------------
Try-Step "Kerberos: disable RC4/DES domain-wide (AES only)" {
    Set-GPRegistryValue -Name $DDP `
        -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" `
        -ValueName "SupportedEncryptionTypes" -Type DWord -Value 2147483640 | Out-Null
}

# --- Anomalies: DC audit policy does not collect key events (+10) --------------
# Enable the key subcategories (also improves our Wazuh detection coverage).
Try-Step "Enable key DC audit subcategories" {
    $subs = @(
        "Kerberos Authentication Service",
        "Kerberos Service Ticket Operations",
        "Credential Validation",
        "Logon","Logoff","Account Lockout",
        "User Account Management","Security Group Management",
        "Directory Service Access","Directory Service Changes",
        "Process Creation"
    )
    foreach ($s in $subs) { auditpol /set /subcategory:"$s" /success:enable /failure:enable | Out-Null }
}

# --- Anomalies: LAPS not installed (+15) -> enable Windows LAPS ----------------
Try-Step "Windows LAPS: extend schema + permissions + policy" {
    Update-LapsADSchema -Confirm:$false
    Set-LapsADComputerSelfPermission -Identity "CN=Computers,DC=lab,DC=internal" | Out-Null
    Set-GPRegistryValue -Name $DDP -Key "HKLM\Software\Microsoft\Policies\LAPS" `
        -ValueName "BackupDirectory" -Type DWord -Value 2 | Out-Null
    Set-GPRegistryValue -Name $DDP -Key "HKLM\Software\Microsoft\Policies\LAPS" `
        -ValueName "PasswordAgeDays" -Type DWord -Value 30 | Out-Null
}

Write-Host ""
Write-Host "Applying Group Policy locally..." -ForegroundColor Cyan
gpupdate /force | Out-Null

Write-Host ""
Write-Host "Done. NOTE: run 'gpupdate /force' on WIN11-01 too, then re-run PingCastle." -ForegroundColor Green
Write-Host "Residual by design: 'only 1 DC' (+5) needs a second DC - out of scope for this lab." -ForegroundColor Yellow
