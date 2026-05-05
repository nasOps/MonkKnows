
# Brakeman
*Statisk sikkerhedsscanner til Ruby — analyserer kildekoden for SQL injection, XSS og lignende.*

**Er vi enige i fundene?** Ja.
**Hvad har vi rettet?** Alle fund ved introduktionen af toolet.
**Hvad har vi ignoreret?** Ingenting.
**Hvorfor?** —

# bundler-audit
*Tjekker Gemfile.lock mod kendte CVEs i Ruby-gems.*

**Er vi enige i fundene?** Ja.
**Hvad har vi rettet?** Alle fund.
**Hvad har vi ignoreret?** Ingenting.
**Hvorfor?** —

# CodeRabbit
*AI-drevet code review — kommenterer automatisk på alle PRs.*

**Er vi enige i fundene?** Størstedelen.
**Hvad har vi rettet?** Sikkerhedsrelaterede fund: SSH-fingerprinting, JSON-validering, CSP-headers, Nginx mount-sti.
**Hvad har vi ignoreret?** Nitpicks, dokumentationsforslag, konfigurationskonventioner og Grafana-eksponering.
**Hvorfor?** Sikkerhedsfund prioriteres; konventioner og dokumentation er lavere prioritet inden for projektets tidsramme.

**41 PRs** med CodeRabbit-aktivitet fundet (ca. 153 kode-kommentarer + 95 issue-kommentarer).

## Enige i og rettet

**PR #96 – Nginx port-eksponering** Port 4567 var stadig eksponeret på web-servicen, stik imod PRens formål. Rettet med commit "Removed exposing the ports".

**PR #106 – JSON type-validering** CodeRabbit pegede på at `.each { |k, v| }` ville crashe hvis parsed JSON ikke var et hash (array/primitiver). Rettet med hash-validering + content-type header på parse-fejl. Noteret i Choices & Challenges.

**PR #162 – CSP + SameSite cookies (delvis)** Konfliktende CSP-headers og forkert SameSite-konfiguration. Rettet med en commit specifikt til det — men efterfølgende måtte headerne gøres mindre restriktive af funktionalitetshensyn.

**PR #170 – SSH StrictHostKeyChecking** `StrictHostKeyChecking=no` i CD-pipelinen. Rettet ved at tilføje known hosts med fingerprint-verificering. Stor sikkerhedsforbedring.

**PR #182 – Nginx mount-sti** Config blev mounted til forkert sti (`conf.d/default.conf` i stedet for `nginx.conf`). Rettet i `docker-compose.prod.yml`.

## Uenige i eller ignoreret

**PR #89 – `.coderabbit.yaml` navngivning** CodeRabbit krævede at config-filen hedder `.coderabbit.yaml` i repo-roden. I stedet blev en workflow-fil oprettet under `.github/workflows/`. Filen eksisterer ikke i standardformat i dag.

**PR #88 – Docker `latest`-tag** CodeRabbit anbefalede immutable image-tags i stedet for `:latest` for reproducible deploys og rollback-mulighed. `docker-compose.prod.yml` bruger stadig `:latest`.

**PR #165 – Smoke test URL/port-konfiguration** Advarsler om CI smoke test URL og CD-workflow-konfiguration. Ingen commits der eksplicit adresserer det.

**PR #102 – Dokumentation** Tomme sektioner og uafsluttet retrospektiv. Lavprioritets-cleanup der ser ud til at være udsat.

**Grafana eksponeret på offentlig IP** CodeRabbit anbefalede at binde Grafana til `127.0.0.1` og tilgå den via SSH-tunnel. Vi valgte bevidst at beholde den på `0.0.0.0:3000`, da SSH-tunnel tilføjer friktion for alle teammedlemmer i et kortlivet skoleprojekt. Grafana er sikret med krævet login, deaktiveret signup og deaktiveret anonym adgang. I et produktionsmiljø ville vi binde til localhost og placere en nginx reverse proxy med TLS foran.

## Mønster

|                      | Antal PRs |
| -------------------- | --------- |
| Enige & rettet       | ~6        |
| Uenige/ignoreret     | ~4        |
| Delvis implementeret | ~3        |

**Tendenser:** Sikkerhedsrelaterede fund (SSH, CSP, JSON-validering) tog vi generelt seriøst. Konfigurationskonventioner (navngivning, image-tagging) afviste vi. Dokumentationsforslag blev typisk udskudt.

# Hadolint
*Linter til Dockerfile — tjekker for best practices.*

**Er vi enige i fundene?** Ja.
**Hvad har vi rettet?** Non-root user.
**Hvad har vi ignoreret?** Pinning af base image med digest (`ruby:3.2-slim` er et flydende tag).
**Hvorfor?** Automatiske sikkerhedsopdateringer i base imaget vurderes vigtigere end strikt reproducerbarhed i dette projekt.

# OWASP ZAP
*Passiv baseline-scan mod den kørende applikation — rapporterer runtime-sårbarheder og manglende sikkerhedsheaders.*

**Er vi enige i fundene?** Overordnet ja.
**Hvad har vi rettet?** Sikkerhedsheaders i nginx (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy).
**Hvad har vi ignoreret?** Informationelle advarsler og Node.js 20 deprecation-advarsel i CF-workflowet.
**Hvorfor?** Informationelle advarsler kræver ikke handling. CF-workflowet producerer følgende advarsel: `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02` kører på Node.js 20, som fjernes fra GitHub Actions den 16. september 2026. Vi ser bevidst bort fra dette, da projektsimulationen afsluttes inden da.

# RuboCop
*Kodekvalitet og konsistens for Ruby — enforcer style guide og bedste praksisser.*

**Er vi enige i fundene?** Ja.
**Hvad har vi rettet?** Størstedelen af fund løbende.
**Hvad har vi ignoreret?** Metodelængde-reglen, som vi har lempet i konfigurationen.
**Hvorfor?** Ruby er et nyt sprog for teamet; pragmatiske lempelser var nødvendige. Set i bakspejlet bidrog det til øget kompleksitet — uddybes under SonarCloud.

# SonarCloud
*Analyserer teknisk gæld, kompleksitet og kodekvalitet på tværs af hele codebasen.*

**Er vi enige i fundene?** Ja, målingerne er korrekte.
**Hvad har vi rettet?** Ingenting — kompleksiteten er opstået gradvist over tid.
**Hvad har vi ignoreret?** Cyklomatisk og kognitiv kompleksitet i `app.rb` og `function_app.py`.
**Hvorfor?** Se nedenfor.

## Cyklomatisk kompleksitet

Cyklomatisk kompleksitet tæller antallet af uafhængige stier gennem koden — hver `if`, `elsif`, `case`, `while`, `&&` og `||` tilføjer 1.

| Fil | Cyklomatisk kompleksitet |
|-----|--------------------------|
| `ruby-sinatra/app.rb` | 60 |
| `azure-function/function_app.py` | 31 |
| `ruby-sinatra/services/weather_service.rb` | 11 |
| `scripts/migrate_sqlite_to_pg.rb` | 10 |
| **Total** | **155** |

`POST /api/pages` illustrerer problemet: routen indeholder fem separate forgreningspunkter (autentificering, to valideringer, filtrering og duplikatfjernelse), der hver tilføjer en ny sti gennem koden. Det samlede tal for `app.rb` afspejler derudover at mange routes og forretningslogik er samlet ét sted — et klassisk Sinatra-mønster.

Sinatra pålægger ingen struktur for opdeling af routes og forretningslogik — i modsætning til Rails, der tvinger én controller per resource. Vi valgte bevidst at samle al logik i `app.rb`, da applikationen var lille og en fladere struktur virkede passende. Vi blev opmærksomme på kompleksitetsmålingerne for sent i forløbet til at en større omstrukturering var realistisk.

## Kognitiv kompleksitet

Kognitiv kompleksitet måler, hvor svær koden er at læse og forstå — i modsætning til cyklomatisk kompleksitet straffer den dyb nesting hårdere end simpel forgrening.

| Fil | Kognitiv kompleksitet |
|-----|----------------------|
| `ruby-sinatra/app.rb` | 71 |
| `azure-function/function_app.py` | 26 |
| `scripts/migrate_sqlite_to_pg.rb` | 6 |
| **Total** | **127** |

Den høje score i `app.rb` skyldes primært at `POST /api/pages` har tre separate ansvar i én route: autentificering, validering og dataindsættelse. `before`/`after`-hooks og `track_user_activity` bidrager yderligere med nestede betingelser og rescue-blokke, der er vokset over tid.

Den korrekte løsning ville være at udtrække disse ansvar i dedikerede service-objekter. Dette er blevet nedprioriteret til fordel for at levere features og infrastruktur inden for projektets tidsramme.

# Trivy
*Scanner Docker-imaget for kendte CVEs inden push til GHCR.*

**Er vi enige i fundene?** Ja.
**Hvad har vi rettet?** Kritiske CVEs med tilgængelig patch.
**Hvad har vi ignoreret?** Non-critical CVEs og CVEs uden tilgængelig patch.
**Hvorfor?** Sårbarheder uden patch kan vi ikke handle på; non-critical fund vurderes acceptable for projektets skala.

# Konklusion

**Er vi enige i fundene?**
Overordnet ja. Fundene fra RuboCop, Brakeman, Hadolint og bundler-audit var legitime og handlede vi på. SonarClouds kompleksitetsmålinger er teknisk korrekte, men afspejler et bevidst arkitekturvalg snarere end sjusk. OWASP ZAPs og Trivys fund er acceptable for projektets skala.

**Hvad har vi rettet?**
Sikkerhedssårbarheder fra bundler-audit og Brakeman, Dockerfile-advarsler fra Hadolint, kodestilsproblemer fra RuboCop samt kritiske sikkerhedsfund fra CodeRabbit (SSH-fingerprinting, JSON-validering, CSP-headers).

**Hvad har vi ignoreret?**
Falske positive fra Brakeman, informationelle advarsler fra OWASP ZAP, non-critical og unfixable CVEs fra Trivy, nitpicks fra CodeRabbit samt den høje kompleksitet i `app.rb` og `function_app.py`.

**Hvorfor?**
Falske positive og informationelle advarsler kræver ikke handling. Kompleksiteten i `app.rb` var et bevidst valg om en flad struktur tilpasset applikationens størrelse — vi introducerede SonarCloud for sent til at en omstrukturering var realistisk inden for tidsrammen.
