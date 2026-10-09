# AD + Wazuh SOC-labb — sammanfattning (svenska)

Ett egenbyggt Active Directory-nätverk som övervakas med SIEM-verktyget **Wazuh**,
attackeras från **Kali Linux** och därefter härdas. För varje teknik finns en
detektionsregel, en incidentrapport och en verifierad åtgärd. Allt är skriptat och
reproducerbart.

> Portföljprojekt av en IT-säkerhetstekniker-studerande (TUC Yrkeshögskola, Linköping)
> inför LIA. Den fullständiga dokumentationen är på engelska i [`README.md`](../README.md).

## Vad projektet visar

- **Bygga och driva en AD-domän** (Windows Server 2025) med användare, grupper, OU och ett tjänstekonto.
- **Driftsätta ett SIEM** (Wazuh) med Sysmon och agenter på Windows-klienterna.
- **Offensiv testning** av 4 MITRE ATT&CK-tekniker från Kali.
- **Detektionsutveckling** — läsa telemetrin, hitta luckor och skriva egna Wazuh-regler som larmar.
- **Härdning** — åtgärda varje fynd och **testa om** för att bevisa att åtgärden fungerar, samt en PingCastle-granskning som gick från **45 → 15 / 100**.

## Miljö

Alla virtuella maskiner körs på en **isolerad** Hyper-V-switch (`LAB-Isolated`,
10.10.10.0/24) utan väg till värddatorn eller internet — attacktrafiken lämnar aldrig labbet.

| Dator | Roll | OS | IP |
|-------|------|----|----|
| DC01 | Domänkontrollant + DNS | Windows Server 2025 | 10.10.10.10 |
| WAZUH01 | SIEM (Wazuh) | Ubuntu Server 24.04 | 10.10.10.20 |
| WIN11-01 | Domänklient | Windows 11 Pro | 10.10.10.101 |
| KALI01 | Angripare | Kali Linux | 10.10.10.50 |

## Attacker och detektion

| # | Teknik (ATT&CK) | Resultat | Detektion |
|---|-----------------|----------|-----------|
| 01 | Nätverksskanning — *T1046* | Kartlade DC:ns tjänster | **Blindfläck** — agenter ser inte paket |
| 02 | Kerberoasting — *T1558.003* | Knäckte `svc-sql` offline | Tyst som standard → **egen regel 100100** |
| 03 | Lösenordsspray — *T1110.003* | Många misslyckade inloggningar | **Upptäcks direkt** (regel 60204) |
| 04 | AS-REP roasting — *T1558.004* | Knäckte `b.berg` offline | Tyst som standard → **egen regel 100101** |

**Lärdom:** ett SIEM är starkast mot högljutt autentiseringsmissbruk och svagast mot
tyst missbruk som ser normalt ut — eller sådant som aldrig når en värdlogg. Att veta
skillnaden är den centrala analytikerkunskapen.

## Härdning

Varje åtgärd testades om för att bevisa att attacken inte längre fungerar:
AS-REP roasting gav "inga träffar", Kerberoasting-biljetten blev AES256 (ej knäckbar), och
lösenordsspray låser nu kontot efter 5 försök. PingCastle-poängen gick från **45 till 15 / 100**
(Privileged Accounts 40 → 0). Återstående 15 är en dokumenterad, accepterad risk
(enda labb-DC:n + två ändringsstyrda inställningar).

## Verktyg

Hyper-V · Windows Server 2025 · Windows 11 · Ubuntu 24.04 · Wazuh 4.14 · Sysmon ·
Kali Linux · netexec · impacket · John the Ripper · PingCastle · MITRE ATT&CK
