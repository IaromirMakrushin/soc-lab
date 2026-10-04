# Phase 5 — Hardening Summary

Date: 2026-10-02. Applied with [scripts/11-Harden-Domain.ps1](../scripts/11-Harden-Domain.ps1).

## Baseline (PingCastle 4.0.0.20, before)
| Category | Score | Rules matched |
|----------|------:|--------------:|
| **Domain Risk Level (max)** | **45/100** | |
| Stale Objects | 45 | 11 |
| Privileged Accounts | 40 | 4 |
| Trusts | 0 | 0 |
| Anomalies | 45 | 13 |

Screenshots: docs/screenshots/20-pingcastle-before.png, 20b-pingcastle-before-riskmodel.png

## Fixes applied (each maps to an incident report)
| # | Fix | Addresses |
|---|-----|-----------|
| 1 | Re-enabled Kerberos pre-authentication on b.berg; audited the domain for others | AS-REP roasting (report 04) |
| 2 | Set `msDS-SupportedEncryptionTypes = 24` (AES only, no RC4) on svc-sql and b.berg | Kerberoasting crackability (report 02) |
| 3 | Reset svc-sql to a 30-char random password (gMSA recommended in production) | Weak service password (report 02) |
| 4 | Account lockout policy: 5 attempts / 15-min lockout / 15-min window | Password spraying & brute force (report 03) |

## Re-tests — proof the fixes work
| Attack | Before | After | Evidence |
|--------|--------|-------|----------|
| AS-REP roasting | `b.berg` hash harvested + cracked | **"No entries found"** — not roastable | 22-asrep-fixed.png |
| Kerberoasting | RC4 (`$23$`) ticket, cracked to `Password1` | **AES256 (`$18$`) ticket, 0 cracked** | 23, 24 |
| Password spray / brute | unlimited failed guesses | **account locks after 5** (`USER_ACCOUNT_LOCKED`) | 25, 26 |

All three previously-successful attacks now fail. The remediation is verified by
re-execution, not just by configuration review.

## PingCastle (after)
| Category | Before | After |
|----------|-------:|------:|
| Domain Risk Level (max) | 45 | **45** |
| Stale Objects | 45 | **40** |
| Privileged Accounts | 40 | 40 |
| Trusts | 0 | 0 |
| Anomalies | 45 | 45 |

Screenshots: 27-pingcastle-after.png, 28-pingcastle-after-riskmodel.png

## Analysis — why the headline score barely moved (and why that's the point)
The overall score is the **maximum** of the four categories, and it is driven by
**Anomalies (45)** and **Stale Objects**. Our fixes were **account-scoped** — they
remediated the exact paths we exploited — but PingCastle also scores **domain-wide
and systemic** settings that account-level changes do not touch:

- **"Old authentication protocols"** stays flagged because **RC4 is still enabled
  domain-wide** (we only set two accounts to AES, not the domain Kerberos policy).
- **"Weak password"** reflects the **domain password policy** (min length, age), not
  individual account passwords.
- Other anomalies (audit config, backups, AD Recycle Bin = disabled) are untouched.

**Lesson:** targeted fixes close specific attack paths (proven by the re-tests), but
lowering a domain's overall risk score requires **broad, iterative hardening**, not a
handful of account edits. A single number does not capture "are we safe?" — you have
to read the findings.

## Iteration 2 — systemic hardening (drove the score down)
Reading the PingCastle rule details, each scored rule was targeted by points.

Applied with [scripts/12-Harden-Domain-Systemic.ps1](../scripts/12-Harden-Domain-Systemic.ps1),
[13-Harden-Privileged.ps1](../scripts/13-Harden-Privileged.ps1) and
[14-Harden-krbtgt-AES.ps1](../scripts/14-Harden-krbtgt-AES.ps1), plus two GPO
security settings via GPMC:

| Fix | Rule cleared | Points |
|-----|--------------|-------:|
| Min password length 14 | Password length < 8 | −10 |
| ms-DS-MachineAccountQuota = 0 | Non-admins can join 10 computers | −10 |
| Declared AD subnet 10.10.10.0/24 | Subnet not declared | −5 |
| AES on all SPN accounts incl krbtgt | Service account without AES (most) | — |
| Hardened UNC paths (SYSVOL/NETLOGON) | Hardened paths weakened | −5 |
| Windows LAPS (schema + policy) | LAPS not installed | −15 |
| Admin accounts "cannot be delegated" | Admin not sensitive/not-delegated | −20 |
| Emptied Schema Admins | Schema Admins not empty | −10 |
| Enabled AD Recycle Bin | Recycle Bin not enabled | −10 |
| GPO: LAN Manager auth level = NTLMv2 only | LM/NTLMv1 allowed | −15 |
| GPO: advanced DC audit policy | (see residuals) | — |

## Final PingCastle result
| Category | Before | After acct fixes | After systemic |
|----------|-------:|-----------------:|---------------:|
| **Domain Risk Level** | **45** | 45 | **15** |
| Stale Objects | 45 | 40 | 10 |
| Privileged Accounts | 40 | 40 | **0** |
| Anomalies | 45 | 45 | 15 |
| Trusts | 0 | 0 | 0 |

**Overall 45 → 15 (-67%).** Screenshots: 29–34.

## Residual findings (documented, not fixed)
| Finding | Points | Why it remains |
|---------|-------:|----------------|
| Only 1 domain controller | +5 | A second DC needs another server — out of scope for a single-host lab. |
| DC audit policy "key events" | +10 | Advanced-audit GPO was configured in Default Domain Controllers Policy; the rule had not cleared at last scan (GPO/SYSVOL propagation or a specific subcategory PingCastle expects). Remediation is in place; would confirm on a later scan. |
| 1 service account "without AES" | +10 | All SPN accounts (svc-sql, krbtgt, DC01$, WIN11-01$) report AES=True; the residual is likely a client/computer account that still *also* advertises RC4 (WIN11-01$ = 0x1C). Fully clearing it means forcing AES-only on computer accounts, a change with reboot/compat impact better done under change control. |

## Overall lesson
Hardening is **iterative and evidence-driven**: read the scored rules, fix by
points, re-scan, repeat. Account-level fixes alone did not move the headline (45);
systemic GPO/domain changes took it to 15. The last few points are genuine
infrastructure trade-offs (a second DC) or change-controlled settings — which is
exactly how real AD hardening ends: a documented, risk-accepted residual, not zero.
