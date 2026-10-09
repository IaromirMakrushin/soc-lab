# Incident Report 04 — AS-REP Roasting (Credential Access)

| | |
|---|---|
| **Date** | 2026-10-02 |
| **Analyst** | Iaromir Makrushin |
| **Severity** | High (credential compromise, NO credentials required to start) |
| **MITRE ATT&CK** | T1558.004 — Steal or Forge Kerberos Tickets: AS-REP Roasting |
| **Source** | KALI01 (10.10.10.50) |
| **Target** | b.berg (account with Kerberos pre-authentication disabled) |

## Summary
The account `b.berg` had **"Do not require Kerberos pre-authentication"** set. For
such accounts the KDC will return an AS-REP (the first stage of login) to *anyone*
who asks, without the requester proving knowledge of the password. Part of that
reply is encrypted with the user's password hash, so it can be cracked offline.
Unlike Kerberoasting, AS-REP roasting needs **no valid domain credentials** to
obtain the hash.

## Pre-condition created in the lab (on DC01)
```
Set-ADAccountControl -Identity b.berg -DoesNotRequirePreAuth $true
Set-ADUser b.berg -Replace @{'msDS-SupportedEncryptionTypes'=4}   # RC4 (legacy) -> crackable without GPU
# weak password set to Welcome1 for the crack demo
```

## Attacker actions (on KALI01)
```
nxc ldap 10.10.10.10 -u a.andersson -p '<user password>' --asreproast asrep.txt
cat asrep.txt                                           # $krb5asrep$23$b.berg@...
john --wordlist=/usr/share/wordlists/rockyou.txt --rules asrep.txt
john --show asrep.txt                                   # -> b.berg:Welcome1
```
(Note: with -no-pass, impacket-GetNPUsers can also harvest AS-REP hashes for any
guessed usernames WITHOUT any credentials at all — the true danger of this misconfig.)

## Detection in Wazuh
Event **4768** ("A Kerberos authentication ticket (TGT) was requested") is logged
with **preAuthType 0** when the TGT is issued without pre-authentication — the
AS-REP roasting signature. Like Kerberoasting, this is high-volume normal traffic,
so there is **no alert by default**.

**Custom rule 100101** (detection-rules/local_rules.xml) matches 4768 + preAuthType 0
and fired at **level 12** after deployment and a re-run of the attack:
"Possible AS-REP Roasting - TGT without pre-auth for b.berg".
(docs/screenshots/19-asrep-alert.png)

## Analysis
Same class of blind spot as Kerberoasting: the telemetry (4768) is already in the
SIEM, but the malicious pattern (a TGT with no pre-auth) is not alerted on by
default. A targeted custom rule converts it into a high-severity, named alert. This
is the second custom rule in the project, showing the detection-engineering workflow
generalises across techniques rather than being a one-off.

## Recommendation / Hardening
1. **Never disable Kerberos pre-authentication.** Audit for it:
   `Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true}` and remediate.
2. **Strong passwords / gMSA** so any harvested AS-REP cannot be cracked.
3. **Enforce AES, disable RC4** (see report 02) — AES AS-REP resists CPU cracking.
4. **Deploy custom rule 100101** to alert on pre-auth-less TGT requests.
