# Architecture Overview — MonkKnows

Overblik over projektstruktur, filer og nøglekommandoer.

---

## Root level

| Fil/Mappe | Formål |
|---|---|
| [docker-compose.dev.yml](../../docker-compose.dev.yml) | Kører PostgreSQL + app + Guard hot-reload til lokal udvikling |
| [docker-compose.prod.yml](../../docker-compose.prod.yml) | Produktions-compose: puller `ghcr.io/nasops/monkknows:latest` + Nginx |
| [nginx.conf](../../nginx.conf) | Reverse proxy til `web:4567`, TLS-terminering, sikkerhedsheaders |
| [CLAUDE.md](../../CLAUDE.md) | Projektkontekst og instruktioner til Claude Code |

---

## `ruby-sinatra/` — Aktiv applikation

Primær arbejdsmappe. Kør alle kommandoer herfra med mindre andet er nævnt.

```bash
# Opsætning (én gang pr. maskine)
bash scripts/install-hooks.sh
bundle config set --local path vendor/bundle
bundle install
```

### Rodfilerne

| Fil | Formål |
|---|---|
| `app.rb` | Hoved-`WhoknowsApp` Sinatra-klasse — alle routes, before-filters, søgelog |
| `config.ru` | Rack entry point — monterer Prometheus middleware, derefter appen |
| `entrypoint.sh` | Docker-opstart: venter på PostgreSQL, kører db:migrate, opretter SQLite logging-DB, starter `rackup` |
| `Dockerfile` | Multi-stage build med `libpq-dev`, HEALTHCHECK, `CMD entrypoint.sh` |
| `Gemfile` | Dependency-deklarationer (Sinatra, ActiveRecord, bcrypt, pg, prometheus-client…) |
| `Rakefile` | Rake task-loader (db:migrate osv.) |
| `Guardfile` | Hot-reload config til Guard i dev/Docker |
| `.rubocop.yml` | RuboCop lint-regler for projektet |
| `.env-template` | Template med påkrævede env vars (SESSION_SECRET, DB_*, osv.) |

```bash
# Start app direkte (uden Docker)
bundle exec rackup config.ru -p 4567 -o 0.0.0.0
```

### `config/`

| Fil | Formål |
|---|---|
| `database.yml` | ActiveRecord DB-config per miljø (dev/prod → PostgreSQL; test → SQLite) |
| `environment.rb` | Indlæser gems, opsætter ActiveRecord-forbindelser inkl. separat SQLite logging-connection |

### `models/`

| Fil | Formål |
|---|---|
| `user.rb` | `User`-model — gradvis MD5→bcrypt-migration via `verify_password?` |
| `page.rb` | `Page`-model — adapter-bevidst søgning (tsvector på PostgreSQL, FTS5 på SQLite) |
| `search_log.rb` | SQLite `SearchLog`-model — gemmer anonymiserede søgninger |
| `user_activity_log.rb` | SQLite-model til logning af login/logout/register-events |
| `exception_log.rb` | SQLite-model til logning af applikationsexceptions |

### `services/`

| Fil | Formål |
|---|---|
| `weather_service.rb` | Henter vejrdata fra OpenWeatherMap med Mutex-beskyttet 10-minutters cache |

### `middleware/`

| Fil | Formål |
|---|---|
| `in_flight_counter.rb` | Rack middleware der tæller in-flight requests som Prometheus gauge |

### `views/`

| Fil | Formål |
|---|---|
| `layout.erb` | Delt HTML-shell — navbar med `id="nav-login"` / `id="nav-logout"` (API-kontrakt) |
| `index.erb` | Søgeside — `id="search-input"`, `id="search-button"`, `id="results"` (API-kontrakt) |
| `login.erb` | Login-formular |
| `register.erb` | Registreringsformular |
| `weather.erb` | Vejr-widget view |
| `reset_password.erb` | Password reset-formular (flow fjernet fra app.rb, view beholdt) |

### `db/`

| Fil | Formål |
|---|---|
| `schema.rb` | ActiveRecord-genereret schema-snapshot (kilde til sandhed for DB-struktur) |
| `migrate/` | ActiveRecord migrations — søgelogs, aktivitetslogs, exceptionlogs, result counts |
| `migrate_to_bcrypt.rb` | Engangsscript til bulk-migration af MD5-passwords til bcrypt |
| `migrate_to_fts5.rb` | Engangsscript der tilføjer SQLite FTS5 fuldtekstindeks |
| `migrate_to_tsvector.rb` | Engangsscript der tilføjer PostgreSQL tsvector fuldtekstindeks |
| `add_indexes.rb` | Engangsscript der tilføjer performance-indekser |
| `fix_password_not_null.rb` | Engangsfiks for `password`-kolonnens nullability |
| `flag_all_users_for_reset.rb` | Brugt efter sikkerhedsbrud 2026 til at tvinge password-reset (kolonne siden droppet) |

```bash
bundle exec rake db:create              # opret DB
bundle exec rake db:schema:load         # indlæs schema fra schema.rb
bundle exec rake db:migrate             # kør ventende migrations
ruby db/migrate_to_tsvector.rb          # tsvector FTS-indeks (PostgreSQL)
```

### `lib/tasks/`

| Fil | Formål |
|---|---|
| `migrate_logs.rake` | Rake task der migrerer gamle logdata til nye ActiveRecord log-tabeller |

```bash
bundle exec rake data:migrate_logs
```

### `spec/`

| Fil | Formål |
|---|---|
| `spec_helper.rb` | RSpec-config — SimpleCov, in-memory SQLite-opsætning, delte helpers |
| `unit/user_spec.rb` | Hurtige unit tests for `User`-modellen (password-hashing, validering) |
| `integration/app_spec.rb` | rack-test integrationstests for alle API-endpoints |
| `integration/contract_spec.rb` | OpenAPI contract-validering via `committee`-gem |
| `integration/accessibility_spec.rb` | HTML-tilgængelighedstjek |
| `e2e/tests/` | Playwright browser-tests: smoke, search, login, register |

```bash
bundle exec rspec                                                        # unit + integration
bundle exec rspec spec/integration/app_spec.rb --format documentation   # kun integration
bundle exec rubocop                                                      # lint
bundle exec rubocop -a                                                   # auto-fix (safe)
bundle exec brakeman                                                     # sikkerhedsanalyse
bundle exec bundler-audit                                                # CVE-scan af Gemfile.lock

# E2E — kræver kørende app med RACK_ENV=e2e + PostgreSQL (fra spec/e2e/)
npm install && npx playwright install
RACK_ENV=e2e bundle exec rackup config.ru -p 4567 -o 0.0.0.0
npx playwright test
```

---

## `docker-compose.dev.yml` — Development stack

Starter PostgreSQL + app + Guard hot-reload. Kører automatisk `db:create → db:schema:load → db:migrate → migrate_to_tsvector` ved opstart.

```bash
docker compose -f docker-compose.dev.yml up            # start
docker compose -f docker-compose.dev.yml up --build    # rebuild (efter Gemfile-ændringer)
docker compose -f docker-compose.dev.yml logs -f web   # app-logs
docker compose -f docker-compose.dev.yml logs -f db    # db-logs
docker compose -f docker-compose.dev.yml down -v       # stop + ryd volumes
```

---

## `docker-compose.prod.yml` — Produktion (lokal test)

```bash
docker compose -f docker-compose.prod.yml up                                             # byg og kør lokalt
docker compose -f docker-compose.prod.yml pull && docker compose -f docker-compose.prod.yml up -d  # pull + start
```

---

## `monitoring/` — Observability-stack

| Fil | Formål |
|---|---|
| `docker-compose.monitoring.yml` | Kører Prometheus + Grafana på monitoring-VM |
| `prometheus.yml` | Scrape-config — ét job der skraber `https://monkknows.dk/metrics` |
| `grafana/provisioning/` | Auto-provisionerer Prometheus-datasource og dashboard-mappe ved Grafana-opstart |
| `grafana/dashboards/monkknows.json` | Hoved-Grafana-dashboard for app-metrics |
| `grafana/dashboards/monkknows-operations.json` | Operations-Grafana-dashboard |

```bash
docker compose -f monitoring/docker-compose.monitoring.yml up     # start Prometheus + Grafana
docker compose -f monitoring/docker-compose.monitoring.yml down   # stop
```

---

## `scripts/` — Ops-tooling

| Fil | Formål |
|---|---|
| `install-hooks.sh` | Éngangsopsætning af git pre-commit hooks per maskine |
| `migrate_sqlite_to_pg.rb` | Éngangsdatamigration fra SQLite → PostgreSQL (allerede kørt) |
| `cutover_to_pg.sh` | Aktiverer PostgreSQL i produktion (allerede kørt) |
| `rollback_to_sqlite.sh` | Nødfallback til SQLite hvis PostgreSQL fejler |
| `local-backup.sh` | Ugentligt lokalt backup-pull fra monitoring-VM via cron |

```bash
bash scripts/local-backup.sh            # manuel backup-pull fra monitoring-VM

# One-off (allerede kørt i prod — kør kun i nødssituation)
ruby scripts/migrate_sqlite_to_pg.rb    # datamigration SQLite → PostgreSQL
bash scripts/cutover_to_pg.sh           # aktivér PostgreSQL i prod
bash scripts/rollback_to_sqlite.sh      # rollback til SQLite
```

---

## `.github/workflows/` — CI/CD

| Fil | Formål |
|---|---|
| `ci.yml` | 6-job pipeline: audit → brakeman → hadolint → build+test → smoke → e2e |
| `cd.yml` | 3-job deploy: build+Trivy-scan → push GHCR → SSH-deploy til app-VM |
| `cd-monitoring.yml` | Deployer Prometheus/Grafana-config til monitoring-VM når `monitoring/` ændres |

---

## Produktion — ops (SSH)

```bash
# App-VM
ssh monkknows 'docker ps'
ssh monkknows 'docker logs app-web-1 --tail 100'
curl -I https://monkknows.dk/

# Monitoring-VM
ssh monkknows-monitoring 'docker ps'
ssh monkknows-monitoring 'cat /opt/monkknows-db/backups/backup.log'
```

---

## `legacy-flask/` — Kun reference

Den originale Python/Flask-app (oprindelse 2009, migreret til Python 3.14). Deployes ikke — beholdes som migreringsreference og til sammenligning med Sinatra-porten.

---

## `docs/` — Dokumentation

| Fil | Formål |
|---|---|
| `choices-and-challenges/Choices and Challenges.md` | ADR-lignende log over alle større tekniske beslutninger — kritisk eksamensdokument |
| `openapi/whoknows-spec.json` | Autoritativ OpenAPI-spec fra Anders (kilde til sandhed for API-kontrakt) |
| `specs/2026-04-14-postgresql-migration-design.md` | Fuldt PostgreSQL-migrationsdesign-dokument |
| `branching-strategi/` | Rationalisering af den tilpassede GitHub Flow-branchingstrategi |
| `codebase/Issues-with-code-base.md` | Prioriteret liste over legacy Flask-sikkerhedsproblemer og Sinatra-mitigeringer |
| `dependency-graph/` | Migrationsrækkefølge og arkitekturdiagram |
