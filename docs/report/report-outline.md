# Rapport-outline — MonkKnows

Max 4 sider (~9.600 tegn ekskl. billeder). Rækkefølgen sikrer at læseren har kontekst til hvert afsnit.

---

## 0. Forside/header
Gruppenavn, navne, KEA-mails, GitHub usernames. Ikke en hel side — bare en blok øverst.

---

## 1. Systemarkitektur *(tung på diagrammer, let på tekst)*

Start her — læseren har ingen kontekst. Et arkitekturdiagram der viser:
- VM1 (app: Docker, Nginx, Sinatra) → VM2 (PostgreSQL, Prometheus, Grafana)
- Trafikflow: bruger → Nginx (TLS) → Sinatra app → PostgreSQL
- Evt. GitHub Actions → GHCR → SSH deploy

*Formål: giver læseren det mentale billede der refereres til i resten af rapporten.*

---

## 2. CI/CD Pipeline

Naturlig forlængelse — nu ved læseren hvad der deployes, nu forklares *hvordan det kommer derud*. Overvej et flowdiagram eller tabel:
- CI: Rubocop → Brakeman → bundler-audit → Hadolint → build+test → smoke test → Playwright E2E
- CD: build → Trivy scan → push GHCR → deploy via SSH
- Nævn CodeRabbit og OWASP ZAP

*Formål: viser DevOps-modenheden i jeres pipeline.*

---

## 3. Monitoring & Observabilitet

Nu ved læseren hvad der kører og hvordan det deployes — næste spørgsmål er: *hvad sker der efter deploy?*
- Prometheus scraper app-metrics
- Grafana dashboards
- Hvad monitorerer I? (fx request rate, fejlrate, DB-forbindelser)
- Evt. screenshot af et dashboard

*Formål: lukker løkken fra deploy til drift.*

---

## 4. Kvalitet & Sikkerhed

Samlet afsnit der samler de tværgående ting:
- Testing: RSpec (unit/integration), kontrakt-test via `committee`-gem (validerer API-responses mod OpenAPI-spec), Playwright (E2E), SQLite in-memory vs. PostgreSQL
- Security scanning: Brakeman, bundler-audit, Trivy, OWASP ZAP, SonarCloud
- Docker: multi-stage build, non-root user

*Formål: viser at I tænker på sikkerhed og kvalitet på tværs af hele stacken.*

---

## Den røde tråd

```
Hvad er systemet?
  → Arkitekturdiagram giver kontekst

Hvordan kommer kode i produktion?
  → CI/CD pipeline

Hvad sker der efter deploy?
  → Monitoring

Hvad sikrer at det hele er sikkert og kvalitetssikret?
  → Kvalitet & Sikkerhed
```

---

## Praktiske råd

- **Diagrammer > tekst** — et godt arkitekturdiagram kan erstatte 400 tegn. Brug dem aktivt.
- **Undgå at beskrive *hvad* værktøjerne er** — censoren ved hvad Prometheus er. Skriv *hvordan I bruger det* og *hvad I monitorerer*.
- **Database-migrationen** (SQLite → PostgreSQL) er et godt eksempel på en konkret DevOps-beslutning — overvej at nævne det kort under arkitektur eller CI/CD.
- **Holdbeskrivelsen** kan stå i headeren — den behøver ikke et separat afsnit.
