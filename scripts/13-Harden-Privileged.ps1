#Requires -RunAsAdministrator
#
# 13-Harden-Privileged.ps1
# Phase 5, iteration 3: clear the Privileged Accounts findings (the current
# PingCastle ceiling). All three are safe, immediate AD changes. Run on DC01.
#
Import-Module ActiveDirectory

function Try-Step($name, [scriptblock]$code) {
    Write-Host "== $name ==" -ForegroundColor Cyan
    try { & $code; Write-Host "   OK" -ForegroundColor Green }
    catch { Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red }
}

# --- Privileged: admin accounts not marked sensitive/cannot-be-delegated (+20) -
# Set the NOT_DELEGATED flag on every protected (adminCount=1) user, so their
# credentials can never be delegated to another service.
Try-Step "Mark admin accounts 'sensitive, cannot be delegated'" {
    Get-ADUser -LDAPFilter "(&(adminCount=1)(objectCategory=person))" |
        ForEach-Object {
            Set-ADAccountControl -Identity $_ -AccountNotDelegated $true
            Write-Host "   flagged $($_.SamAccountName)"
        }
}

# --- Privileged: Schema Admins not empty (+10) --------------------------------
# Schema Admins should be empty except during a planned schema change. Members
# are removed here (re-add temporarily when a schema change is actually needed).
Try-Step "Empty the Schema Admins group" {
    Get-ADGroupMember -Identity "Schema Admins" | ForEach-Object {
        Remove-ADGroupMember -Identity "Schema Admins" -Members $_ -Confirm:$false
        Write-Host "   removed $($_.SamAccountName)"
    }
}

# --- Privileged + Stale: AD Recycle Bin not enabled (+10) ---------------------
# One-way enable (cannot be turned off) - standard best practice.
Try-Step "Enable the AD Recycle Bin" {
    Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' `
        -Scope ForestOrConfigurationSet -Target 'lab.internal' -Confirm:$false
}

Write-Host ""
Write-Host "Done. Re-run PingCastle (AD changes are immediate, no gpupdate needed)." -ForegroundColor Green
