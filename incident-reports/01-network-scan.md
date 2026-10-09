# Incident Report 01 — Network Port Scan (Reconnaissance)

| | |
|---|---|
| **Date** | 2026-10-02 |
| **Analyst** | Iaromir Makrushin |
| **Severity** | Low–Medium (reconnaissance, no compromise) |
| **MITRE ATT&CK** | T1046 — Network Service Discovery; T1595 — Active Scanning |
| **Source** | KALI01 (10.10.10.50) |
| **Target** | DC01 (10.10.10.10) and the 10.10.10.0/24 network |

## Summary
An unauthorised host (KALI01) performed a host-discovery sweep of the whole
10.10.10.0/24 network, followed by a full TCP SYN + service-version scan of the
domain controller DC01. This is classic pre-attack reconnaissance: the attacker
is mapping which machines exist and which services they expose.

## Attacker actions (observed on KALI01)
```
nmap -sn 10.10.10.0/24                              # host discovery: found .10 .20 .101 .50
sudo nmap -sS -sV -p- --min-rate 1000 10.10.10.10  # full port + version scan of DC01
```

## Open ports found on DC01
The scan returned the classic Active Directory domain-controller fingerprint
(nmap even reported `Host: DC01; OS: Windows`, domain `lab.internal`):

| Port | Service | Why it matters |
|------|---------|----------------|
| 389 / 636 | LDAP / LDAPS | Directory queries — enumerate users, groups, computers |
| 3268 / 3269 | Global Catalog | Forest-wide directory search |
| 88 | Kerberos | Authentication — target for Kerberoasting / AS-REP roasting |
| 464 | kpasswd | Kerberos password change |
| 445 / 139 | SMB | File shares, remote exec, lateral movement |
| 135 + 49664-49717 | RPC + dynamic RPC | Remote management, DCE/RPC attacks |
| 53 | DNS | Runs on the DC |
| 593 | RPC over HTTP | |
| 5985 | WinRM (HTTP) | Remote PowerShell |
| 9389 | AD Web Services | PowerShell AD module backend |

The combination of 88 + 389 + 3268 + 445 is an unambiguous "this is a domain
controller" signature. An attacker now knows exactly what to target next.

Screenshot: docs/screenshots/08-nmap-dc-scan.png

## Detection in Wazuh
**The scan was NOT detected.** Findings during the scan window:

- `agent.name:DC01` → 1,035 events, but all were routine **Windows Logon/Logoff**
  (rule 60106 / 60137). None related to the scan.
  (docs/screenshots/09-dc-only-logons.png)
- `agent.name:DC01 and rule.groups:*firewall*` → **No results.** Windows Firewall
  logs are not being forwarded to Wazuh. (docs/screenshots/10-no-firewall-alerts.png)
- Windows event **5156** (Filtering Platform "connection allowed") → not present.
  This event requires the audit sub-category *Filtering Platform Connection* to be
  enabled, which is **off by default**.

## Analysis
This is a genuine, instructive **detection gap**, not a configuration mistake:

1. The Wazuh agent is **host-based** — it reads Windows event logs, not raw network
   packets. A TCP port scan is network-layer traffic and leaves little host-log trace.
2. The one host event that would reveal per-connection activity (5156) is disabled by
   default, so nothing is logged even though the scan clearly happened.

A real SOC would catch this at the **network layer**, not the host: an IDS/IPS
(e.g. Suricata), NetFlow, or firewall logs show the tell-tale pattern of one source
touching many ports/hosts in seconds.

## Recommendation / Hardening
1. **Enable Filtering Platform auditing** on the DC so connection attempts are logged
   (`auditpol /set /subcategory:"Filtering Platform Connection" /success:enable`),
   then add a Wazuh rule that fires when one source IP hits many distinct ports in a
   short window. (Planned: detection-rules/ custom scan rule.)
2. **Deploy a network IDS** (Suricata) on a mirror/inline point for true network
   visibility — the correct long-term fix.
3. **Reduce attack surface**: a domain controller must expose AD services, but RDP
   (3389) and WinRM (5985) should be restricted to admin hosts via host firewall.
4. **Network segmentation**: workstations should not be able to port-scan the DC at all.
