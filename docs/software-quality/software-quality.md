
# Brakeman

Brakeman er en statisk sikkerhedsscanner til Ruby, der analyserer kildekoden for kendte sårbarheder som SQL injection og XSS. Vi er enige i fundene og har rettet de legitime advarsler. Brakeman er kendt for at producere falske positive, særligt around mass assignment og dynamiske queries — disse har vi vurderet og bevidst ignoreret, da de ikke var reelle sårbarheder i vores kontekst.

# CodeRabbit

CodeRabbit gennemgår automatisk alle PRs og kommenterer på potentielle problemer i koden. Vi er enige i størstedelen af fundene og har aktivt handlet på dem. Vi har ignoreret kommentarer, der omhandlede strukturen i Choices and Challenges.md samt nitpicks-kommentarer.


**41 PRs** med CodeRabbit-aktivitet fundet (ca. 153 kode-kommentarer + 95 issue-kommentarer).



## Enige i og rettet

**PR #96 – Nginx port-eksponering** Port 4567 var stadig eksponeret på web-servicen, stik imod PRens formål. Rettet med commit "Removed exposing the ports".

**PR #106 – JSON type-validering** CodeRabbit pegede på at `.each { |k, v| }` ville crashe hvis parsed JSON ikke var et hash (array/primitiver). Rettet med hash-validering + content-type header på parse-fejl. Noteret i Choices & Challenges.

**PR #162 – CSP + SameSite cookies (delvis)** Konfliktende CSP-headers og forkert SameSite-konfiguration. Rettet med en commit specifikt til det — men efterfølgende måtte headerne gøres mindre restriktive af funktionalitetshensyn.

**PR #170 – SSH StrictHostKeyChecking** `StrictHostKeyChecking=no` i CD-pipelinen. Rettet ved at tilføje known hosts med fingerprint-verificering. Stor sikkerhedsforbedring.

**PR #182 – Nginx mount-sti** Config blev mounted til forkert sti (`conf.d/default.conf` i stedet for `nginx.conf`). Rettet i `docker-compose.prod.yml`.



## Uenige i eller ignoreret

**PR #89 – `.coderabbit.yaml` navngivning** CodeRabbit krævede at config-filen hedder `.coderabbit.yaml` i repo-roden. I stedet blev en workflow-fil oprettet under `.github/workflows/`. Filen eksisterer ikke i standardformat i dag.

**PR #88 – Docker `latest`-tag** CodeRabbit anbefalede immutable image-tags i stedet for `:latest` for reproducible deploys og rollback-mulighed. `docker-compose.prod.yml` bruger stadig `:latest`. (`.dockerignore` med `*.db` ser dog ud til at være tilføjet et sted.)

**PR #165 – Smoke test URL/port-konfiguration** Advarsler om CI smoke test URL og CD-workflow-konfiguration. Ingen commits der eksplicit adresserer det.

**PR #102 – Dokumentation** Tomme sektioner og uafsluttet retrospektiv. Lavprioritets-cleanup der ser ud til at være udsat.

**Grafana eksponeret på offentlig IP** CodeRabbit anbefalede at binde Grafana til `127.0.0.1` og tilgå den via SSH-tunnel. Vi valgte bevidst at beholde den på `0.0.0.0:3000`, da SSH-tunnel tilføjer friktion for alle teammedlemmer i et kortlivet skoleprojekt. Grafana er sikret med krævet login, deaktiveret signup og deaktiveret anonym adgang. I et produktionsmiljø ville vi binde til localhost og placere en nginx reverse proxy med TLS foran.



## Mønster

|                      | Antal PRs |
| -------------------- | --------- |
| Enige & rettet       | ~6        |
| Uenige/ignoreret     | ~4        |
| Delvis implementeret | ~3        |

**Tendenser:** Sikkerhedsrelaterede fund (SSH, CSP, JSON-validering) tog I generelt seriøst. Konfigurationskonventioner (navngivning, image-tagging) afviste I. Dokumentationsforslag blev typisk udskudt.

# bundler-audit

bundler-audit tjekker `Gemfile.lock` mod kendte CVEs i Ruby-gems. Vi er enige i alle fund og har løbende opdateret afhængigheder, når sårbarheder er blevet opdaget. Vi har ikke ignoreret nogen fund fra dette tool.

# Hadolint

Hadolint linter vores Dockerfile og tjekker for best practices. Vi er enige i fundene og har rettet dem — herunder brug af non-root user og pinning af base images. Vi har ikke ignoreret nogen fund.

# Trivy

Trivy scanner Docker-imaget for kendte CVEs inden det pushes til GHCR. Vi har konfigureret det til kun at blokere ved `CRITICAL`-fund uden tilgængelig patch (`ignore-unfixed: true`). Dette er et bevidst valg: sårbarheder uden en tilgængelig rettelse kan vi ikke handle på, og non-critical fund vurderes acceptable for et projekt i denne skala.

# OWASP ZAP

OWASP ZAP kører en passiv baseline-scan mod den kørende applikation og rapporterer manglende sikkerhedsheaders og lignende. Vi er overordnet enige i fundene. Scanneren er konfigureret til ikke at fejle CI (`-I`), da den primært bruges til overblik. Vi har adresseret de mest kritiske headers og accepteret de resterende informationelle advarsler.

# RuboCop
Har opsnappet mange potentielle problemer i koden, og har været en uvurderlig hjælp til at holde koden ren og konsistent. Vi har aktivt lempet på nogle regler i konfigurationen (eks. metodelængde), da Ruby er et helt nyt programmeringssprog. 
Det var en balancegang mellem at følge best practices og pragmatik, men set i bakspejlet (efter vi for sent introducerede SonarCloud) kan vi se, at vores kompleksitet er steget deraf. Det uddybes nærmere i afsnittet om SonarCloud.

# SonarCloud 

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


# Konklusion

**Er vi enige i fundene?**
Overordnet ja. Fundene fra RuboCop, Brakeman, Hadolint og bundler-audit var legitime og handlede vi på. SonarClouds kompleksitetsmålinger er teknisk korrekte, men afspejler et bevidst arkitekturvalg snarere end sjusk. OWASP ZAPs og Trivys fund er acceptable for projektets skala.

**Hvad har vi rettet?**
Sikkerhedssårbarheder fra bundler-audit og Brakeman, Dockerfile-advarsler fra Hadolint, kodestilsproblemer fra RuboCop samt kritiske sikkerhedsfund fra CodeRabbit (SSH-fingerprinting, JSON-validering, CSP-headers).

**Hvad har vi ignoreret?**
Falske positive fra Brakeman, informationelle advarsler fra OWASP ZAP, non-critical og unfixable CVEs fra Trivy, nitpicks fra CodeRabbit samt den høje kompleksitet i `app.rb` og `function_app.py`.

**Hvorfor?**
Falske positive og informationelle advarsler kræver ikke handling. Kompleksiteten i `app.rb` var et bevidst valg om en flad struktur tilpasset applikationens størrelse — vi introducerede SonarCloud for sent til at en omstrukturering var realistisk inden for tidsrammen.