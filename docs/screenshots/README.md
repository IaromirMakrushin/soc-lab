# Screenshot checklist

Evidence for the GitHub README. Never include passwords, password prompts with visible
text, or the Wazuh install summary.

| # | File | What it shows | Status |
|---|------|---------------|--------|
| 01 | 01-hyperv-vms.png | Hyper-V Manager: DC01, WAZUH01, WIN11-01, KALI01 | done |
| 02 | 02-isolated-switch.png | Virtual Switch Manager: LAB-Isolated = Private network | done |
| 03 | 03-ad-users.png | DC01, AD Users and Computers: OU "Lab" with users + groups | done |
| 04 | 04-win11-domain.png | WIN11-01 logged in as LAB\a.andersson, domain = lab.internal | done |
| 05 | 05-wazuh-agents.png | Wazuh dashboard: DC01 + WIN11-01 active | done |
| 06 | 06-sysmon-events.png | Threat Hunting: Sysmon events arriving from both agents | done |
| 07 | 07-sysmon-event-detail.png | One expanded Sysmon event (process creation fields) | done |
| 08 | 08-nmap-dc-scan.png | nmap full port+version scan of DC01 from Kali | done |
| 09 | 09-dc-only-logons.png | DC01 events during scan = only logon/logoff, scan invisible | done |
| 10 | 10-no-firewall-alerts.png | No firewall alerts for the scan = detection gap | done |
| 11 | 11-kerberoast-hash.webp | Kerberoast TGS hash for svc-sql captured on Kali | done |
| 12 | 12-kerberoast-cracked.png | john cracks svc-sql ticket -> Password1 | done |
| 13 | 13-kerberoast-alert.webp | Custom rule 100100 fires: Kerberoasting detected (level 12) | done |
| 14 | 14-password-spray.webp | Password spray: 9 failed LDAP binds from Kali | done |
| 15 | 15-spray-detected-default.png | Spray caught by DEFAULT: rule 60204 Multiple Logon Failures (level 10) | done |
| 16 | 16-spray-level10-alerts.png | Filtered to level>=10: two rule 60204 brute-force alerts | done |
| 17 | 17-asrep-hash.webp | AS-REP hash for b.berg harvested (no creds for the hash) | done |
| 18 | 18-asrep-cracked.webp | john cracks AS-REP -> b.berg:Welcome1 | done |
| 19 | 19-asrep-alert.png | Custom rule 100101 fires: AS-REP Roasting detected (level 12) | done |
| 20 | 20-pingcastle-before.png | PingCastle baseline: Domain Risk 45/100 (before hardening) | done |
| 20b | 20b-pingcastle-before-riskmodel.png | PingCastle risk matrix (before): old auth protocols + weak password flagged | done |
| 21 | 21-hardening-applied.png | Hardening script output: AES=24, pre-auth fixed, lockout set | done |
| 22 | 22-asrep-fixed.png | After hardening: AS-REP roast finds nothing (pre-auth fixed) | done |
| 23 | 23-kerberoast-now-aes.webp | After hardening: Kerberoast ticket is now AES256 ($18), not RC4 | done |
| 24 | 24-kerberoast-uncrackable.webp | After hardening: AES ticket won't crack (0 cracked) | done |
| 25 | 25-lockout-triggered.webp | After hardening: account locks after 5 tries (USER_ACCOUNT_LOCKED) | done |
| 26 | 26-lockout-confirmed-dc.png | DC01 confirms c.carlsson LockedOut=True | done |
| 27 | 27-pingcastle-after.png | PingCastle after: Stale 45->40, overall 45 (Anomalies dominates) | done |
| 28 | 28-pingcastle-after-riskmodel.png | PingCastle risk matrix (after hardening) | done |
| 29 | 29-systemic-hardening-applied.png | Systemic hardening script: all 9 steps OK | done |
| 30 | 30-pingcastle-after-systemic.webp | PingCastle after systemic hardening: overall 40, Anomalies 45->15, Stale 40->25 | done |
| 31 | 31-privileged-hardening-applied.png | Privileged hardening: admin not-delegated, Schema Admins emptied, Recycle Bin on | done |
| 32 | 32-pingcastle-after-privileged.png | PingCastle: overall 25, Privileged 40->0 | done |
| 33 | 33-krbtgt-aes.png | All SPN accounts (incl krbtgt) now AES=True | done |
| 34 | 34-pingcastle-after-gpo.png | PingCastle after GPO work: overall 15 (from 45) | done |
