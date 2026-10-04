# Incident Report 02 — Kerberoasting (Credential Access)

| | |
|---|---|
| **Date** | 2026-10-02 |
| **Analyst** | (your name) |
| **Severity** | High (service-account credential compromise) |
| **MITRE ATT&CK** | T1558.003 — Steal or Forge Kerberos Tickets: Kerberoasting |
| **Source** | KALI01 (10.10.10.50), authenticated as a standard domain user |
| **Target** | svc-sql (service account with SPN MSSQLSvc/sql01.lab.internal:1433) |

## Summary
Using only a standard domain user's credentials (a.andersson), the attacker
requested a Kerberos service ticket (TGS) for the service account `svc-sql`,
extracted the ticket hash, and cracked it **offline** to recover the password
`Password1`. No password-guessing traffic hit the DC, and no account lockouts
occurred — the cracking happened entirely on the attacker's machine.

## Attacker actions (on KALI01)
```
# Request the service ticket (any domain user can do this)
nxc ldap 10.10.10.10 -u a.andersson -p '<user password>' --kerberoasting kerberoast.txt

# Crack offline with a wordlist + mangling rules
john --wordlist=/usr/share/wordlists/rockyou.txt --rules kerberoast.txt
john --show kerberoast.txt     # -> svc-sql:Password1
```

## Why it worked
1. **Any authenticated user** can request a TGS for any account that has an SPN —
   this is normal Kerberos behaviour, not a bug.
2. The ticket is encrypted with the **service account's password hash**, so a weak
   password (`Password1`) falls to an offline dictionary attack in seconds.
3. The account allowed **RC4** (`msDS-SupportedEncryptionTypes = 4`). RC4 tickets
   crack far faster than AES. (Note: Server 2025 defaults to AES256; RC4 was set
   here to simulate a common legacy service account — see hardening.)

## Detection in Wazuh
- Event **4769** ("A Kerberos service ticket was requested") IS generated — the DC
  audit subcategory *Kerberos Service Ticket Operations* was already set to Success,
  and the Wazuh agent forwards the Security channel.
- **But there was no alert by default.** 4769 is high-volume normal traffic, so the
  default ruleset does not raise it. The event data reaches the SIEM but nothing
  flags the malicious pattern.
- **Fix: custom rule 100100** (detection-rules/local_rules.xml) fires at level 12
  when a 4769 uses the weak **RC4 cipher (0x17)** for a *user* service account —
  the signature of Kerberoasting. **Verified firing**: after deploying rule 100100
  and re-running the attack, Wazuh raised a single level-12 alert on DC01,
  "Possible Kerberoasting - RC4 ticket for svc-sql..."
  (docs/screenshots/13-kerberoast-alert.webp).

## Analysis
This mirrors the lesson from the port scan: the raw telemetry existed, but
detection required a deliberately authored rule. The difference is that here the
data was already in the SIEM — only the *analytic* was missing. Writing rule 100100
turns a silent, high-impact attack into a high-severity alert naming the service,
the requesting user, and the source IP.

## Recommendation / Hardening
1. **Strong service-account passwords** (25+ random chars) or, better, **Group
   Managed Service Accounts (gMSA)** with automatic 120-char passwords — makes
   offline cracking infeasible.
2. **Enforce AES, disable RC4** for service accounts
   (`msDS-SupportedEncryptionTypes = 0x18`, AES128+AES256). A roasted AES ticket
   resisted CPU cracking in this very lab.
3. **Deploy custom rule 100100** so RC4 service-ticket requests are alerted on.
4. **Least privilege / monitoring**: alert when one account requests many distinct
   SPNs in a short time (bulk roasting).
