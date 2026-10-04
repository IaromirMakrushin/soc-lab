#Requires -RunAsAdministrator
#
# 14-Harden-krbtgt-AES.ps1
# Clears PingCastle "service account(s) without AES support". The usual culprit is
# krbtgt (it has the kadmin/changepw SPN). Sets AES on krbtgt and reports every
# SPN-bearing account's encryption types for verification. Run on DC01.
#
Import-Module ActiveDirectory

Write-Host "== SPN accounts and their msDS-SupportedEncryptionTypes (before) ==" -ForegroundColor Cyan
Get-ADObject -LDAPFilter "(servicePrincipalName=*)" `
    -Properties samAccountName, msDS-SupportedEncryptionTypes |
    ForEach-Object {
        $enc = $_.'msDS-SupportedEncryptionTypes'
        $aes = ($enc -ne $null) -and (($enc -band 0x18) -ne 0)
        "{0,-20} enc={1} AES={2}" -f $_.samAccountName, $enc, $aes
    }

Write-Host "`n== Setting krbtgt to AES128+AES256 (24) ==" -ForegroundColor Cyan
try {
    Set-ADUser -Identity krbtgt -Replace @{'msDS-SupportedEncryptionTypes'=24}
    Write-Host "   OK" -ForegroundColor Green
} catch { Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "`nDone. Re-run PingCastle to confirm the AES finding clears." -ForegroundColor Green
