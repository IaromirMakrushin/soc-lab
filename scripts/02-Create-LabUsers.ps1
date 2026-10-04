#
# 02-Create-LabUsers.ps1
# Populates the lab.internal domain with an OU, groups, standard users and one
# service account, so the lab resembles a small real organisation.
# Run as Administrator on DC01, in 64-bit Windows PowerShell, after the domain exists.
#
# NOTE: the passwords below are deliberately simple LAB-ONLY values for an
# isolated, offline test domain. Never reuse them anywhere real.
#

Import-Module ActiveDirectory

$ouPath   = "OU=Lab,DC=lab,DC=internal"
$userPw   = ConvertTo-SecureString "LabUserP@ss1" -AsPlainText -Force
# svc-sql: intentionally WEAK but policy-compliant (upper+lower+digit, >=7).
# "Password1" = rockyou's "password1" + a capitalize rule, so john cracks it in
# seconds. ("Summer2026!" left the account disabled on Server 2025; "P@ssw0rd"
# met complexity but its leet @/0 are NOT in rockyou, so basic rules missed it.)
$svcPw    = ConvertTo-SecureString "Password1" -AsPlainText -Force

# --- Organisational Unit ---------------------------------------------------
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Lab'" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name "Lab" -Path "DC=lab,DC=internal" -ProtectedFromAccidentalDeletion $false
}

# --- Groups ----------------------------------------------------------------
$groups = "IT-Admins","Finance","HR","Helpdesk"
foreach ($g in $groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $ouPath
    }
}

# --- Standard users --------------------------------------------------------
# format: SamAccountName, DisplayName, Group
$users = @(
    @("a.andersson","Anna Andersson","Finance"),
    @("b.berg","Bjorn Berg","HR"),
    @("c.carlsson","Cecilia Carlsson","Helpdesk"),
    @("d.dahl","David Dahl","Finance"),
    @("e.ek","Erik Ek","IT-Admins")
)
foreach ($u in $users) {
    $sam, $name, $grp = $u
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $name -SamAccountName $sam `
            -UserPrincipalName "$sam@lab.internal" `
            -AccountPassword $userPw -Enabled $true `
            -Path $ouPath -ChangePasswordAtLogon $false
        Add-ADGroupMember -Identity $grp -Members $sam
    }
}

# --- Service account (used later for SPN-based testing) --------------------
# A normal pattern in real AD: an account that runs a service and has an SPN.
if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc-sql'" -ErrorAction SilentlyContinue)) {
    New-ADUser -Name "svc-sql" -SamAccountName "svc-sql" `
        -UserPrincipalName "svc-sql@lab.internal" `
        -AccountPassword $svcPw -Enabled $true `
        -Path $ouPath -PasswordNeverExpires $true
    setspn -s MSSQLSvc/sql01.lab.internal:1433 svc-sql
}
# Make sure it is actually enabled (a non-compliant password on creation can
# leave the account disabled, which makes it invisible to Kerberoasting).
Enable-ADAccount -Identity svc-sql -ErrorAction SilentlyContinue

Write-Host "Done. Users, groups and service account created in $ouPath" -ForegroundColor Green
Get-ADUser -Filter * -SearchBase $ouPath | Select-Object Name, SamAccountName | Format-Table -AutoSize
