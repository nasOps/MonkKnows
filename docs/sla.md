# Service Level Agreement (SLA) — MonkKnows

_Gyldig fra: 2026-05-17_
_Tjeneste: MonkKnows søge- og vejrtjeneste_
_URL: [https://monkknows.dk](https://monkknows.dk)_

---

## 1. Serviceomfang

SLA'en dækker følgende endpoints på `https://monkknows.dk`:

| Endpoint | Beskrivelse |
|---|---|
| `GET /` | Forsiden — søgeformular |
| `GET /api/search` | Søge-API (JSON) |
| `GET /weather` | Vejrside |
| `GET /api/weather` | Vejr-API (JSON) |
| `GET /register` og `POST /api/register` | Brugerregistrering |
| `GET /login` og `POST /api/login` | Login |
| `GET /api/logout` og `GET /logout` | Logout |
| `GET /health` | Healthcheck-endpoint (intern og monitoring) |

Følgende er **ikke** dækket af denne SLA:

- Tredjepartstjenester som OpenWeatherMap API (bruges af vejr-endpoints — nedetid på denne tjeneste påvirker vejrfunktionaliteten men tæller ikke med i MonkKnows' oppetidsmål)
- Azure Function `monkknows-crawler` (crawling/indexering sker asynkront og er ikke en kernetjeneste)
- Grafana-dashboardet på VM2 (intern drifts-tool, ikke en brugerfacing tjeneste)
- Prometheus/metrics-endpoint (intern)
- `GET /api/search-logs/top` og `POST /api/pages` (interne crawler-endpoints, kræver API-nøgle)
- `GET /hello` (dev-endpoint uden funktionel betydning)

---

## 2. Performancemål

### Oppetid

| Mål | Værdi |
|---|---|
| **Månedlig oppetid** | **95 %** |
| Tilladt nedetid pr. måned | ~36 timer |

95 % er et bevidst konservativt tal. MonkKnows kører på én enkelt Azure VM (App-VM) uden redundans eller load balancing. Deploy via CD-pipelinen medfører en genstart af app-containeren; cold-start er konfigureret med op til 300 sekunders start_period før containeren erklæres healthy. En oppetidsgaranti på 99 % eller derover ville ikke være realistisk eller ærlig for dette setup.

Planlagt vedligeholdelse (deploys, certifikatfornyelse, database-migrationer) er **inkluderet** i oppetidsberegningen.

### Svartid

Konkrete p95-svartidsmål skal defineres på baggrund af faktiske Grafana-målinger (Operations-dashboard, latency-paneler). Tallene opdateres her når baseline er etableret.

Svartider måles fra Prometheus-scrape på `https://monkknows.dk/metrics`.

---

## 3. Hændelses- og gendannelsesstider

MonkKnows er et skoleprojekt med et team på tre studerende. Der er ingen 24/7-vagtordning eller SLA-kompensation. Nedenstående er de realistiske responstider inden for normale åbningstider (08:00–22:00 dansk tid, hverdage).

| Hændelsestype | Eksempel | Mål for bekræftelse | Mål for løsning |
|---|---|---|---|
| Kritisk nedetid | Appen svarer ikke / 5xx på alle requests | 1 time | 4 timer |
| Serviceforringelse | Forhøjede fejlrater, langsom respons | 2 timer | 8 timer |
| Mindre fejl | Enkelt endpoint fejler, ikke-kritisk funktion | Næste hverdag | Inden for 3 hverdage |

**Overvågning:** Discord-alerts via `monitor_logs.sh` (kører hvert 5. minut, scanner container-logs for 4xx/5xx-mønstre). Prometheus + Grafana på VM2 bruges til at diagnosticere hændelser.

**Der ydes ingen kompensation** ved overskridelse af disse mål, da tjenesten leveres gratis som en del af et uddannelsesprojekt.

---

## 4. Sikkerhedsforanstaltninger

| Foranstaltning | Detalje |
|---|---|
| **HTTPS / TLS** | Al trafik krypteres via Let's Encrypt (certifikat på `monkknows.dk` + `www.monkknows.dk`). HTTP (port 80) redirecter automatisk til HTTPS via nginx 301. HSTS aktiveret med `max-age=31536000; includeSubDomains`. |
| **Sikkerhedsheaders** | `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Content-Security-Policy`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (camera, microphone, geolocation deaktiveret). |
| **Brute-force-beskyttelse** | `fail2ban` aktiv på App-VM, banner IP'er ved gentagne fejlede SSH-loginforsøg. |
| **Session-sikkerhed** | Sessions signeres med `SESSION_SECRET` (krævet i produktion — appen starter ikke uden). Cookies sendes kun over HTTPS. |
| **Databaseadgang** | PostgreSQL på VM2 er kun tilgængeligt fra App-VM's IP-adresse og et privat subnet (pg_hba.conf whitelist). Adgangskode gemt som Docker secret (`chmod 600`). |
| **Containerisering** | Appen kører som ikke-root bruger i en multi-stage Docker-container. Ressource-limits: 256 MB RAM og 0,5 CPU for app-containeren. |
| **Secrets-håndtering** | Ingen hemmeligheder i kode eller Docker-image. CI/CD-pipelinen bygger `.env` fra GitHub Secrets og SCP'er den til serveren ved deploy. |
| **Sårbarhedsscanning** | Brakeman (statisk analyse), Bundler Audit (kendte sårbarheder i gems) og Trivy (container image scan) køres i CI/CD-pipeline ved hvert PR og deploy. OWASP ZAP køres i CF-pipeline. |
| **Lynis** | Lynis sikkerhedsaudit kører nightly på App-VM via `lynis.timer`. |

**Kendte begrænsninger:**
- Grafana-dashboardet er tilgængeligt på port 3000 uden TLS. Det er beskyttet med brugernavn/password, men credentials sendes ukrypteret.
- Prometheus (port 9090) og PostgreSQL (port 5432) er eksponeret på `0.0.0.0` uden Azure NSG-whitelist. Adgangskontrol sker på applikationsniveau (pg_hba.conf) og netværksniveau på VM-niveau.

---

## 5. Compliance

| Område | Status |
|---|---|
| **GDPR** | MonkKnows registrerer brugerkonti med brugernavn, e-mailadresse og adgangskode (bcrypt-hashed). E-mailadressen er personhenførbar og opbevares kun for at identificere kontoen. Vi opbevarer ikke navn eller andre oplysninger ud over brugernavn og e-mail. Søgeforespørgsler logges i PostgreSQL med felterne: søgeterm, endpoint, HTTP-metode, statuskode, varighed, antal resultater og en daglig-roterende trunkeret SHA256-hash af IP-adressen (16 tegn). Loggen er ikke koblet til specifikke brugerkonti. Brugere kan anmode om sletning af deres konto ved at kontakte teamet (se nedenfor). |
| **Adgangskodehåndtering** | Adgangskoder hashes med bcrypt inden lagring. Ingen adgangskoder opbevares i klartekst. |
| **Datalagring** | Data lagres på Azure VM'er i Sverige (App-VM og Monitoring-VM begge i Gävleborg; Azure Function i Sweden Central). PostgreSQL-data backuppes dagligt med 7-dages retention. |
| **Dataminimering** | Vi opbevarer ikke mere data end nødvendigt for tjenestens drift. |

MonkKnows er et uddannelsesprojekt og er ikke certificeret efter ISO 27001.

---

## 6. Kontakt og ansvar

MonkKnows drives af:

- Andreas (Gabel1998)
- Nima (hajisan)
- Sofie (sobr0002)

Spørgsmål om denne SLA eller anmodninger om datasletning kan rettes via GitHub Issues på projektets repository.

---

_Dette dokument er senest revideret: 2026-05-17_
