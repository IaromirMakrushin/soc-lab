# Incident Report 03 — Password Spraying (Credential Access)

| | |
|---|---|
| **Date** | 2026-10-02 |
| **Analyst** | (your name) |
| **Severity** | Medium–High (credential access attempt against many accounts) |
| **MITRE ATT&CK** | T1110.003 — Brute Force: Password Spraying |
| **Source** | KALI01 (10.10.10.50) |
| **Target** | All domain accounts via DC01 (10.10.10.10), SMB |

## Summary
The attacker attempted to authenticate to many domain accounts using a single
common password ("one password, many users"). Spraying avoids account lockouts
that a traditional brute force (many passwords, one user) would trigger, while
still testing a large number of accounts.

## Attacker actions (on KALI01)
```
printf '%s\n' Administrator a.andersson b.berg c.carlsson d.dahl e.ek svc-sql > users.txt
nxc smb 10.10.10.10 -u users.txt -p 'Autumn2026!' --continue-on-success
```

## Result of the spray
SMB spraying stalled on Server 2025 (NetBIOS auth timeout), so the spray was run
over **LDAP** instead, which also exercises DC authentication. Every bind with the
wrong password `Autumn2026!` failed, across Administrator, all five standard users
and svc-sql (plus two stray list entries). No account was compromised — a wrong
password was used deliberately to generate failed-logon telemetry.

## Detection in Wazuh — CAUGHT BY DEFAULT
Unlike the scan and the Kerberoast, this attack was detected with **no custom rule**:

| rule.id | rule.description | level |
|---------|------------------|-------|
| 60122 | Logon Failure - Unknown user or bad password | 5 |
| **60204** | **Multiple Windows Logon Failures** | **10** |

Event 4625 ("An account failed to log on") fired ~once per attempt (18 hits across
the SMB + LDAP rounds), and Wazuh's built-in correlation rule **60204** aggregated
the burst into a single level-10 alert. (docs/screenshots/15-spray-detected-default.png)

## Analysis — the detection spectrum
Across the three attacks this lab now shows the full range of SIEM visibility:

| Attack | Telemetry on host? | Default Wazuh alert? | Action needed |
|--------|--------------------|-----------------------|---------------|
| Port scan (01) | No (network-layer) | No | Network IDS / firewall logs |
| Kerberoasting (02) | Yes (4769) | **No** (treated as noise) | **Custom rule 100100** |
| Password spray (03) | Yes (4625) | **Yes** (rule 60204) | None — works out of the box |

A SIEM is strongest at noisy, high-volume authentication abuse (spraying) and
weakest at quiet, "looks-normal" abuse (Kerberoasting) and at anything that never
touches a host log (scanning). Knowing which is which is the core analyst skill.

## Recommendation / Hardening
- **Account lockout policy**: threshold (e.g. 10), observation window, auto-reset —
  slows spraying and forces attackers louder.
- **Ban weak/seasonal passwords** (Azure AD Password Protection or equivalent) so
  guesses like `Autumn2026!` / `Password1` are rejected at change time.
- **MFA** for remote and privileged access.
- **Optional tuning**: add a correlation rule for the specific spray signature —
  many *distinct* accounts failing from one source IP in a short window — to catch
  low-and-slow sprays that stay under rule 60204's per-source threshold.

## Recommendation / Hardening
<!-- - Account lockout policy (threshold + observation window + reset).
     - Strong/complex passwords + banned-password lists (no seasonal passwords).
     - MFA for remote/privileged access.
     - Alert on spray pattern: many distinct accounts failing from one source IP
       in a short window (lower the default threshold / add a correlation rule). -->
