#Requires -RunAsAdministrator
#
# 11-Harden-Domain.ps1
# Phase 5 hardening. Run on DC01 (elevated) as a domain admin.
# Remediates the weaknesses exploited in incident reports 02-04 and sets a
# baseline account-lockout policy. Each change maps to a specific finding.
#
Import-Module ActiveDirectory

Write-Host "== 1. Re-enable Kerberos pre-authentication (fixes AS-REP roasting, report 04) ==" -ForegroundColor Cyan
Set-ADAccountControl -Identity b.berg -DoesNotRequirePreAuth $false
# Audit the whole domain for any other pre-auth-disabled accounts:
Get-ADUser -Filter 'DoesNotRequirePreAuth -eq $true' | Select-Object Name, SamAccountName

Write-Host "== 2. Enforce AES, disable RC4 on service/roastable accounts (fixes Kerberoasting crackability, report 02) ==" -ForegroundColor Cyan
# 24 = 0x18 = AES128 + AES256 only (no RC4/DES)
foreach ($u in "svc-sql","b.berg") {
    Set-ADUser -Identity $u -Replace @{'msDS-SupportedEncryptionTypes'=24}
    Get-ADUser -Identity $u -Properties msDS-SupportedEncryptionTypes |
        Select-Object Name, msDS-SupportedEncryptionTypes
}

Write-Host "== 3. Strong service-account password (fixes weak svc-sql password, report 02) ==" -ForegroundColor Cyan
# 30-char random password -> infeasible to crack even if a ticket is roasted.
Add-Type -AssemblyName System.Web
$strong = [System.Web.Security.Membership]::GeneratePassword(30, 8)
Set-ADAccountPassword -Identity svc-sql -Reset -NewPassword (ConvertTo-SecureString $strong -AsPlainText -Force)
Write-Host "svc-sql password reset to a 30-char random value (not stored in this script)."
# (In production prefer a Group Managed Service Account (gMSA) with auto-rotated 120-char password.)

Write-Host "== 4. Account lockout policy (slows password spraying, report 03) ==" -ForegroundColor Cyan
Set-ADDefaultDomainPasswordPolicy -Identity lab.internal `
    -LockoutThreshold 5 `
    -LockoutDuration (New-TimeSpan -Minutes 15) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 15)
Get-ADDefaultDomainPasswordPolicy -Identity lab.internal |
    Select-Object LockoutThreshold, LockoutDuration, LockoutObservationWindow, MinPasswordLength

Write-Host ""
Write-Host "Hardening applied. Re-run the attacks to confirm they now fail, then re-run PingCastle." -ForegroundColor Green
