# MonkKnows Infrastructure Map

_Sidst opdateret: 2026-05-21_

---

## Oversigt — To Azure VM'er

| VM | Hostname | IP | SSH-alias | Ansvar |
|---|---|---|---|---|
| App-VM | `<APP_VM_HOST>` | `<APP_VM_IP>` | `monkknows` | Sinatra-app, Nginx, TLS |
| Monitoring-VM | `<MONITORING_VM_HOST>` | `<MONITORING_VM_IP>` | `monkknows-monitoring` | Prometheus, Grafana, PostgreSQL, Backup |

SSH-config: `~/.ssh/config` — begge bruger samme SSH-nøgle. Appens PostgreSQL er på Monitoring-VM port 5432.

---

## App-VM (`monkknows`)

### Mappestruktur `/opt/whoknows/`

```text
/opt/whoknows/
├── app/                    # Git-checkout af MonkKnows-repo (remote: GitHub NasOps/MonkKnows)
│   ├── .env                # Runtime secrets (SESSION_SECRET, DB_*, OPENWEATHER_API_KEY)
│   ├── docker-compose.prod.yml   # Aktiv produktions-compose (nginx + web)
│   ├── nginx.conf          # Nginx-config monteret ind i app-nginx-1
│   ├── is_valid_crpat.sh   # Manuel devutil til validering af GitHub CR_PAT
│   ├── whoknows.db         # SQLite-fil bevidst bibeholdt (Nima) — bruges ikke af containere
│   ├── whoknows.db-shm     # SQLite shared-memory fil (bibeholdt)
│   ├── whoknows.db-wal     # SQLite WAL-fil (bibeholdt)
│   ├── ruby-sinatra/       # Aktiv Sinatra app-kildekode
│   │   ├── app.rb          # WhoknowsApp klasse, alle routes, Prometheus gauge, søgelog
│   │   ├── config.ru       # Rack entry point — Prometheus middleware monteres her
│   │   ├── Dockerfile      # Multi-stage build (libpq-dev, HEALTHCHECK, entrypoint.sh)
│   │   ├── config/         # database.yml, environment.rb
│   │   ├── models/         # ActiveRecord-modeller (User, Page, SearchLog m.fl.)
│   │   ├── services/       # WeatherService (Mutex-cached), m.fl.
│   │   ├── views/          # ERB-templates
│   │   ├── public/         # Statiske assets
│   │   └── spec/           # RSpec tests (unit/, integration/, e2e/)
│   ├── legacy-flask/       # Legacy Python Flask-kode (kun reference — kører ikke)
│   └── docs/               # ADR-log, OpenAPI spec, branching-strategi osv.
├── backups/                # Modtager 2 backup-serier (7-dages retention)
│   ├── monkknows_YYYY-MM-DD_HHMM.sql.gz   # PostgreSQL-dumps fra Monitoring-VM (SCP)
│   └── whoknows_YYYYMMDD_HHMMSS.db        # SQLite-snapshots fra db_backup.sh
├── data/                   # Host-side Docker volume root
│   ├── logging/            # Monteret ind i app-web-1 på /app/db/logging
│   │   └── logging.sqlite3 # Søgequery-log (aktiv, ingen backup!)
│   └── whoknows.db         # SQLite-fil (1.9 MB, sidst skrevet 2026-04-16, ingen backup)
└── scripts/                # Ops-scripts (ejes af root)
    ├── health_check.sh     # */5 min — curl /health, forsøger systemctl restart whoknows ved fejl
    ├── db_backup.sh        # Dagligt 03:00 — sqlite3 .backup af data/whoknows.db
    ├── auto_deploy.sh      # */5 min — docker compose pull, start ved "Pull complete"
    └── /usr/local/bin/monitor_logs.sh   # */5 min — scanner container-logs, sender Discord-alert
```

### Containere

| Navn | Image | Status | Porte |
|---|---|---|---|
| `app-web-1` | `ghcr.io/nasops/monkknows:latest` | Up ~45h, **healthy** | 4567 (intern kun) |
| `app-nginx-1` | `nginx:alpine` (1.29.8) | Up 5 dage | `0.0.0.0:80`, `0.0.0.0:443` |

**Healthcheck (`app-web-1`):** `ruby -e "require 'net/http'; ..."` → `GET http://localhost:4567/health`. Defineret i `docker-compose.prod.yml` (overrider Dockerfile's HEALTHCHECK): interval 5s, timeout 3s, retries 30, **start_period 300s** (giver buffer til cold gem-load efter fresh image-pull). CD's deploy-step bruger `docker compose up -d --wait --wait-timeout 600` så pipelinen blokerer indtil healthy.

**Volume mount (`app-web-1`):** `/opt/whoknows/data/logging` → `/app/db/logging` (rw)

**Volume mounts (`app-nginx-1`):** `./nginx.conf`, `/etc/letsencrypt/live/monkknows.dk/`, `/etc/letsencrypt/archive/monkknows.dk/`

### `docker-compose.prod.yml` — Services

**`nginx`:**
- Image: `nginx:alpine`, ports `80:80` + `443:443`
- Mounts: `./nginx.conf`, Let's Encrypt `live/` og `archive/` (begge nødvendige pga. symlinks)
- Limits: 128 MB RAM, 0.25 CPU
- `restart: unless-stopped`, `depends_on: web`

**`web`:**
- Image: `ghcr.io/nasops/monkknows:latest`, intern port 4567 (ikke publiceret til host)
- Volume: `/opt/whoknows/data/logging:/app/db/logging`
- Limits: 256 MB RAM, 0.50 CPU
- `healthcheck`: ruby net/http mod `/health`, interval 5s, timeout 3s, retries 30, start_period 300s
- `restart: unless-stopped`
- Env: `RACK_ENV=production` + alle 6 nøgler fra `.env`

### `nginx.conf` — Nøgle-direktiver

| Direktiv | Værdi |
|---|---|
| HTTP (port 80) | 301 redirect til HTTPS for `monkknows.dk` + `www.monkknows.dk` |
| HTTPS (port 443) | TLS-terminering, proxy til `http://web:4567` |
| `ssl_certificate` | `/etc/letsencrypt/live/monkknows.dk/fullchain.pem` |
| `ssl_certificate_key` | `/etc/letsencrypt/live/monkknows.dk/privkey.pem` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` (1 år HSTS) |
| `Content-Security-Policy` | `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `proxy_pass` | `http://web:4567` (Docker DNS) |
| Forwarded headers | `Host`, `X-Real-IP`, `X-Forwarded-For` |

Ingen upstream-blok, ingen rate limiting, ingen caching-direktiver.

### `.env` — Nøgler (ikke værdier)

| Nøgle | Formål |
|---|---|
| `DB_HOST` | IP på Monitoring-VM's PostgreSQL |
| `DB_USER` | PostgreSQL brugernavn |
| `DB_PASSWORD` | PostgreSQL password |
| `DB_NAME` | PostgreSQL database-navn |
| `SESSION_SECRET` | Signerer Sinatra session-cookies (obligatorisk — raises i prod hvis mangler) |
| `OPENWEATHER_API_KEY` | Tredjeparts vejr-API (WeatherService, Mutex-cached 10 min) |

### TLS / Let's Encrypt

| Egenskab | Værdi |
|---|---|
| Cert-placering | `/etc/letsencrypt/live/monkknows.dk/` (symlinks) |
| Archive | `/etc/letsencrypt/archive/monkknows.dk/` |
| Domæner | `monkknows.dk`, `www.monkknows.dk` (SAN) |
| Nøgle-type | RSA |
| **Udløber** | **2026-07-06 16:29 UTC (74 dage tilbage pr. 2026-04-23)** |
| Renewal | `certbot.timer` (systemd) — kører automatisk på host |
| Mangler | Nginx-container genstartes **ikke** automatisk efter renewal — nye cert-filer indlæses først ved næste `docker compose restart nginx` |

### Scripts

**`/opt/whoknows/scripts/health_check.sh`** (root, oprettet 2026-02-24, **cron-entry fjernet 2026-04-30**)
Curler `http://localhost:4567/health` (5s timeout). Ved fejl: `systemctl restart whoknows` — vil altid fejle fordi appen kun lytter inde i Docker-netværket. Cron-entry fjernet 2026-04-30 (se `docs/runbooks/cleanup-legacy-host.md`); script-filen ligger stadig i `/opt/whoknows/scripts/` for reference.

**`/opt/whoknows/scripts/db_backup.sh`** (root, oprettet 2026-02-24)
`sqlite3 .backup` (WAL-safe) af `/opt/whoknows/data/whoknows.db` → `/opt/whoknows/backups/whoknows_TIMESTAMP.db`. Beholder 7 nyeste. Kører dagligt 03:00.

**`/opt/whoknows/scripts/auto_deploy.sh`** (root, oprettet 2026-03-17, **cron-entry fjernet 2026-04-30**)
`docker compose pull` hvert 5. min. Var alternativ til CD-pipelinens push-baserede deploy, men host'en mistede GHCR-auth-token og pull returnerede `401 Unauthorized` (observeret 2026-04-30 10:40:05 UTC under deploy af PR #275 hvor det racet med CD'ens egen SSH-deploy). Cron-entry fjernet 2026-04-30; script-filen bevaret for reference.

**`/usr/local/bin/monitor_logs.sh`** (root, oprettet 2026-03-19)
Scanner `app-web-1`-logs siden sidste kørsel for `HTTP [45]xx` / `Error` / `error`. Ved match: sender Discord-webhook-alert. **Webhook-URL er hardcoded i scriptet.**

**`/opt/whoknows/app/is_valid_crpat.sh`** (adminuser, oprettet 2026-03-17)
Manuel devutil — tester om en GitHub PAT har korrekte scopes til GHCR. Kører ikke automatisk.

### Cron Jobs (root)

```cron
0   3 * * *   /opt/whoknows/scripts/db_backup.sh >> /var/log/whoknows/db_backup.log 2>&1
*/5 * * * *   /usr/local/bin/monitor_logs.sh >> /var/log/whoknows_monitor.log 2>&1
```

**Fjernet 2026-04-30** (gemt backup: `/root/crontab-backup-2026-04-30.txt`):
- `*/5 * * * * /opt/whoknows/scripts/health_check.sh` — curlede en port der ikke findes på host'en, og kickede `whoknows.service` i en crash-loop
- `*/5 * * * * /opt/whoknows/scripts/auto_deploy.sh` — fejlede med GHCR 401 og racet med CD-pipelinens deploy

**adminuser crontab:** tom.

### Logs

| Sti | Størrelse | Beskrivelse |
|---|---|---|
| `/var/log/whoknows/health_check.log` | 190 KB | Aktiv. Hvert 5. min, men OK-entries kun hvert 6. time. |
| `/var/log/whoknows/health_check.log.1` | 300 KB | Roteret forrige uge. |
| `/var/log/whoknows/db_backup.log` | <1 KB | SQLite backup-log. Sidst: 2026-04-23 03:00. |
| `/var/log/whoknows/deploy.log` | 0 bytes | Tom — ingen auto-deploy siden 2026-04-08. |
| `/var/log/whoknows/deploy.log.1` | 105 bytes | Forrige auto-deploy entry (2026-04-08). |
| `/var/log/whoknows_monitor.log` | 452 KB | Discord-monitor log. Verbose — hvert 5. min. |
| `/var/log/auth.log` | 4.5 MB | SSH login-forsøg (aktiv brute-force-aktivitet). |
| `/var/log/btmp` | 9.7 MB | Fejlede login-forsøg. Stor → betydelig brute-force-trafik. |
| `/var/log/fail2ban.log` | 454 KB | fail2ban aktiv og banner IP'er. |
| `/var/log/lynis.log` | 590 KB | Lynis sikkerhedsaudit — kører via `lynis.timer` (nightly). |
| `/var/log/lynis-report.dat` | 57 KB | Maskinlæsbar Lynis-rapport. |
| `/var/log/nginx/` | 0 bytes | Host-nginx (ikke i brug — app kører i container). |

Container-logs tilgås via `docker logs app-web-1` / `docker logs app-nginx-1`.

### Backups (`/opt/whoknows/backups/`)

To serier med 7-dages rolling retention:

**PostgreSQL-dumps** (fra Monitoring-VM via SCP, dagligt 03:00 UTC):
`monkknows_2026-04-17_0300.sql.gz` → `monkknows_2026-04-23_0300.sql.gz` (ca. 822–872 KB, +8 KB/dag)

**SQLite-snapshots** (lokal `db_backup.sh`, dagligt 03:00):
`whoknows_20260417_030001.db` → `whoknows_20260423_030001.db` (1.9 MB hver)

### Dead Code / Kendte problemer

**`whoknows.service`** (systemd, **masked 2026-04-30**):
- Status: `masked` (symlink til `/dev/null`). `systemctl start/restart` returnerer fejl uden at gøre noget. Bekræftet 2026-04-30 11:23 UTC.
- Oprindelse: uge 3 rbenv-baseret direkte Sinatra-start fra før Docker-migrationen.
- Hvorfor unit'en fejlede: appen kører nu i Docker; unit'en kørte `bundle exec rackup` fra `/home/adminuser/.rbenv/` hvor dev-gems (`guard`, `pry`, `listen`, `ffi`…) ikke er installeret → fejlede med `Bundler::GemNotFound`. Op til 2026-04-30 blev den kicked hver 5. min af `health_check.sh` cron, hvilket gav 5-restart-bursts (en af disse bursts ramte midt i CD-deployet, se "Deploy MTTR observation" nedenfor).
- Backup af unit-filen ligger i `/etc/systemd/system/whoknows.service.disabled-2026-04-30` for rollback.

**Ruby-version mismatch:** CI pinner Ruby 3.2.3; kørende container-image bruger Ruby 3.2.11 (nyere patch).

### Deploy MTTR observation (2026-04-30)

PR #275 deploy'ede succesfuldt, men CD-pipelinens production smoke test markerede deployet rødt. App-containeren var 502 i ~8 minutter før Puma bandt sig til port 4567. Ingen kode-fejl — ren cold-start anomali.

**Tidslinje (UTC):**

| Tid | Hændelse |
|---|---|
| 10:38:33 | PR #275 merget → CD startede |
| 10:40:01 | `auto_deploy.sh` cron kørte → `docker compose pull` fejlede med GHCR 401 (host mangler auth) |
| 10:40:01–10:40:08 | `health_check.sh` cron kickede `whoknows.service` → 5 burst-restarts, alle fejlede med `Bundler::GemNotFound` |
| 10:41:14 | Ny app-container startede (efter CD's SSH-deploy) |
| 10:41:19 | `entrypoint.sh` printede "Running migrations..." |
| 10:41:26 | CD smoke test begyndte at curle `https://monkknows.dk/` |
| 10:42:42 | **Smoke test gav op efter 30 forsøg × 2s = 60s** → CD rød |
| 10:45:01–10:45:08 | Endnu en `whoknows.service` burst (5 restart-forsøg under cold load) |
| 10:49:10 | `bundle exec rake db:migrate` færdig efter **7m 51s** |
| 10:49:14 | Puma bandt til port 4567, app begyndte at svare 200 |

**Målte baselines (live på samme container, varm):**

| Operation | Tid (varm) |
|---|---|
| `bundle exec rake db:migrate` (no-op) | ~2s |
| `bundle exec ruby -e "puts :ok"` | ~815ms |
| 100× PG round-trip VM1→VM2 | ~910ms (~9ms hver) |
| `rake -T` (loader Rakefile + miljø) | ~1.8s |
| Forrige succesfulde deploy (PR #269, 27/4) — smoke test | **5s** |

**Hvad det IKKE var:**

- ❌ Memory pressure (cgroup peak: 163 MiB / 256 MiB limit, ingen OOM, ingen `memory.events`)
- ❌ Manglende gems (`bundle check` siger satisfied)
- ❌ PG locks eller langsom DB (ingen rows i `pg_locks WHERE NOT granted`)
- ❌ Eksterne API-kald i init (`config/environment.rb` er kun `Bundler.require`)
- ❌ Pending migrations (schema_migrations matcher disk)
- ❌ App.rb crash fra #275 (Rakefile loader ikke `app.rb`)

**Mest sandsynlige årsag:**

First-time disk page-in af 64 MB bundle-layer (~80 gems → tusindvis af små `.rb`-reads) på 1-vCPU/847 MiB-host, kombineret med ressource-konkurrence fra `whoknows.service` crash-loop-bursts der præcist ramte deploy-vinduet (10:40 og 10:45). Forrige deploys har klaret cold-load på sekunder — så det er en sammensat anomali, ikke kronisk.

**Bidragende host-side rod:**

Det at `whoknows.service` overhovedet bliver kicked hver 5. min er et symptom på misalignment efter Docker-migrationen — health-check'et curler en port der ikke findes på hosten, og "fix"-handlingen restarter en service der ikke længere er meningen at køre. Cleanup: se `docs/runbooks/cleanup-legacy-host.md`.

### Deploy improvements

Inspireret af MTTR-analyse fra Andreas2 (kollega) + investigation 2026-04-30:

| # | Tiltag | Status | Effort | Effekt |
|---|---|---|---|---|
| 1 | Tilføj `healthcheck` til `docker-compose.prod.yml` (samme mønster som PR #274 indførte til dev) + brug `docker compose up -d --wait --wait-timeout 600` i CD-deploy-step | ✅ **Implementeret 2026-04-30** (denne branch) | ~15 min | Deploy blokerer indtil container er healthy. Smoke test rammer kun en faktisk klar app. Ægte fail-fast via Docker. |
| 2 | Øg smoke test-timeout fra 60s → 300s+ | ⏭️ Ikke nødvendig — option #1 dækker det. Smoke test simplificeret til én curl efter `--wait`. | ~5 min | Maskerer langsomme deploys i stedet for at fejle dem. |
| 3 | Kør `rake db:migrate` som separat one-off container i CD før `up -d` | 📋 Tracked i [#276](https://github.com/nasOps/MonkKnows/issues/276) (efter Mandatory II) | ~30 min | Gammel container fortsætter med at betjene trafik mens migrationer kører. Reducerer **bruger-synlig** nedetid. |
| 4 | Blue-green deploy via Traefik/Caddy med to compose-projekter | ❌ Ikke planlagt | flere timer | Nul nedetid, ægte fail-fast. For tungt til kursusprojekt. |

Bemærk: option 3's hovedgevinst er ikke "migrations er hurtigere" — `rake db:migrate` tager 2s varm. Gevinsten er at swap'en udskydes til ny container er warm-loaded, så brugere ser ikke 502.

---

## Monitoring-VM (`monkknows-monitoring`)

### Mappestruktur

```text
/opt/whoknows/monitoring/           # Prometheus + Grafana compose-projekt
├── docker-compose.monitoring.yml   # Definerer prometheus + grafana services
├── prometheus.yml                  # Scrape-config (1 job: monkknows → https://monkknows.dk/metrics)
├── .env                            # GRAFANA_USER, GRAFANA_PASSWORD
└── grafana/
    ├── provisioning/
    │   ├── datasources/
    │   │   └── datasource.yml      # Provisioner Prometheus-datasource (http://prometheus:9090)
    │   └── dashboards/
    │       └── dashboard.yml       # Provisioner dashboard-provider (fra ./grafana/dashboards/)
    └── dashboards/
        └── monkknows.json          # "MonkKnows User Telemetry" dashboard (9 panels)

/opt/monkknows-db/                  # PostgreSQL compose-projekt
├── docker-compose.yml              # postgres:16-alpine service med secrets + pg_hba.conf mount
├── pg_hba.conf                     # PostgreSQL adgangskontrol (se nedenfor)
├── db_password.txt                 # PostgreSQL password (chmod 600, monteret som Docker secret)
├── backup.sh                       # Dagligt backup-script (pg_dump + SCP til app-VM)
└── backups/                        # Lokale backup-filer + backup.log
    ├── backup.log                  # Log over alle backup-kørsler
    └── monkknows_YYYY-MM-DD_HHMM.sql.gz   # 9 filer (Apr 16–23)

/home/azureuser/
├── .env                            # Kopi af monitoring .env (GRAFANA_USER, GRAFANA_PASSWORD)
└── .ssh/
    ├── id_ed25519                  # Ed25519 privat nøgle til backup SCP
    ├── authorized_keys             # Indgående SSH-nøgler for azureuser (3.0 KB, flere teammedlemmer)
    └── known_hosts                 # Populeres af backup SCP-kørsler
```

### Containere

| Navn | Image | Status | Porte |
|---|---|---|---|
| `monitoring-prometheus-1` | `prom/prometheus:v2.53.4` | Up 44h | `0.0.0.0:9090->9090` |
| `monitoring-grafana-1` | `grafana/grafana:11.6.0` | Up 30h | `0.0.0.0:3000->3000` |
| `monkknows-db-db-1` | `postgres:16-alpine` | Up 6 dage, **healthy** | `0.0.0.0:5432->5432` |

**Docker volumes:**

| Volume | Brugt af |
|---|---|
| `monitoring_prometheus_data` | Prometheus TSDB blokke (90-dages retention) |
| `monitoring_grafana_data` | Grafana persistent state (UI-redigerede dashboards, brugere) |
| `monkknows-db_pgdata` | PostgreSQL data-dir (`/var/lib/postgresql/data`) |

### `docker-compose.monitoring.yml` — Services

**`prometheus`:**
- Image: `prom/prometheus:v2.53.4`, port `9090:9090`
- Mounts: `./prometheus.yml`, named volume `prometheus_data:/prometheus`
- CLI: `--config.file` + `--storage.tsdb.retention.time=90d`
- Limits: 256 MB RAM, 0.50 CPU

**`grafana`:**
- Image: `grafana/grafana:11.6.0`, port `3000:3000`
- Mounts: `grafana_data:/var/lib/grafana`, `./grafana/provisioning`, `./grafana/dashboards`
- Env fra `.env` (`:?` — hard-fail hvis unset). Sign-ups og anonym adgang disabled.
- `depends_on: prometheus`
- Limits: 256 MB RAM, 0.50 CPU

### `prometheus.yml` — Scrape Config

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: monkknows
    scheme: https
    static_configs:
      - targets: ['monkknows.dk']
        labels:
          environment: production
    metrics_path: /metrics
```

Ingen alert-regler, ingen remote_write, ingen recording rules.

### Grafana Dashboard — `monkknows.json`

Titel: **"MonkKnows User Telemetry"** — 9 panels:

| Panel | Type | Metrik |
|---|---|---|
| Total Registered Users | stat | Users-tæller |
| Total Searches | stat | Søge-tæller |
| Zero-Result Searches | stat | Nul-resultat tæller |
| Request Rate per Endpoint (app routes) | timeseries | HTTP request rate |
| Logins per Hour | timeseries | Login-rate (increase()) |
| Searches per Hour | timeseries | Søge-rate (increase()) |
| Error Rate: 4xx vs 5xx | timeseries | HTTP fejl-rate |
| Request Latency (p50, p95) | timeseries | Latency histogrammer |
| Bot/Scanner Traffic (non-app routes) | timeseries | Ikke-app HTTP requests |

### PostgreSQL (`/opt/monkknows-db/docker-compose.yml`)

- Image: `postgres:16-alpine`, port `5432:5432`
- Volume: `pgdata:/var/lib/postgresql/data`
- Bind mounts: `./pg_hba.conf` → `/etc/pg_hba.conf` (rw), `./db_password.txt` → `/run/secrets/db_password` (ro)
- Password-fil: `POSTGRES_PASSWORD_FILE=/run/secrets/db_password`
- Start-command: `postgres -c hba_file=/etc/pg_hba.conf -c listen_addresses='*'`
- Healthcheck: `pg_isready -U monkknows` (interval 10s, 5 retries)

### `pg_hba.conf` — Adgangskontrol

```conf
local   all   all                       trust   # Unix socket (pg_dump i container)
host    all   monkknows  <APP_VM_IP>/32  md5    # App-VM — tilladt med password
host    all   monkknows  <PRIVATE_SUBNET> md5   # Privat subnet — tilladt med password
host    all   all        0.0.0.0/0       reject  # Alle andre afvises
```

### Backup Script (`/opt/monkknows-db/backup.sh`)

Køres af azureuser's cron dagligt 03:00 UTC. Adfærd (med `set -euo pipefail`):
1. `docker exec monkknows-db-db-1 pg_dump -U monkknows monkknows | gzip` → `/opt/monkknows-db/backups/monkknows_YYYY-MM-DD_HHMM.sql.gz`
2. Verifikation: fil må ikke være tom — ellers slet og exit 1
3. `scp` til `adminuser@<APP_VM_IP>:/opt/whoknows/backups/` (`-o StrictHostKeyChecking=no`)
4. Ved succesfuld SCP: `find` på app-VM, slet filer ældre end 7 dage
5. `find /opt/monkknows-db/backups -mtime +7 -delete` — lokal 7-dages retention
6. Al output → `/opt/monkknows-db/backups/backup.log` (via cron-redirect)

### Backup-filer (`/opt/monkknows-db/backups/`)

| Fil | Størrelse | Dato |
|---|---|---|
| `monkknows_2026-04-16_2050.sql.gz` | 820 KB | Apr 16 (manuel test) |
| `monkknows_2026-04-16_2051.sql.gz` | 820 KB | Apr 16 (manuel test) |
| `monkknows_2026-04-17_0300.sql.gz` | 822 KB | Apr 17 |
| `monkknows_2026-04-18_0300.sql.gz` | 829 KB | Apr 18 |
| `monkknows_2026-04-19_0300.sql.gz` | 837 KB | Apr 19 |
| `monkknows_2026-04-20_0300.sql.gz` | 845 KB | Apr 20 |
| `monkknows_2026-04-21_0300.sql.gz` | 853 KB | Apr 21 |
| `monkknows_2026-04-22_0300.sql.gz` | 862 KB | Apr 22 |
| `monkknows_2026-04-23_0300.sql.gz` | 872 KB | Apr 23 |

Voksende ~8 KB/dag — konsistent med aktive database-writes.

### Cron Jobs

**azureuser:**

```cron
0 3 * * *   /opt/monkknows-db/backup.sh >> /opt/monkknows-db/backups/backup.log 2>&1
```

Dagligt 03:00 UTC (05:00 dansk sommertid). **root:** ingen.

### Port-overblik (Monitoring-VM)

| Port | Tjeneste | Lytter | Note |
|---|---|---|---|
| 22 | `sshd` | `0.0.0.0` | Standard SSH |
| 1022 | `sshd` | `0.0.0.0` | Ubuntu release-upgrader safety sshd — auto-spawned af `do-release-upgrade`, ikke et custom service |
| 3000 | Grafana (docker-proxy) | `0.0.0.0` | Ingen TLS-fronting |
| 5432 | PostgreSQL (docker-proxy) | `0.0.0.0` | Kun adgang via pg_hba.conf |
| 9090 | Prometheus (docker-proxy) | `0.0.0.0` | Ingen auth |

---

## Azure Function (`monkknows-crawler`)

Serverless crawler der scraper og indekserer websider baseret på loggede søgninger.

| Egenskab | Værdi |
|----------|-------|
| Navn | `monkknows-crawler` |
| Resource Group | `whoknows-rg` |
| Region | Sweden Central |
| Runtime | Python 3.11 |
| Hosting plan | Flex Consumption (scale to zero) |
| Instance size | 512 MB |

### Triggers

| Trigger | Type | Beskrivelse |
|---------|------|-------------|
| HTTP POST `/api/crawl` | Manuel | Invokation via Azure Portal eller curl |
| Timer `0 0 2 * * 0` | Schedule | Søndag 02:00 UTC — aktiveres ved behov |

### Application Settings

| Navn | Beskrivelse |
|------|-------------|
| `APP_URL` | `https://monkknows.dk` |
| `CRAWLER_API_KEY` | Delt hemmelighed med Sinatra-appen |

### Deploy

Deployes via `.github/workflows/deploy-crawler.yml` ved push til `main` (kun ved ændringer i `azure-function/**`) eller `workflow_dispatch`.

Se: `docs/specs/2026-04-28-scraping-indexing-design.md`

---

## Kendte Gaps / Hygiejne-problemer

> Disse er ikke blokerende, men kandidater til **Choices & Challenges**-dokumentet.

| Problem | Konsekvens | VM |
|---|---|---|
| Port 5432, 9090, 3000 eksponeret på `0.0.0.0` uden Azure NSG-whitelist | Alle tre services tilgængelige fra internet | Monitoring |
| ~~`health_check.sh` kalder `systemctl restart whoknows` ved fejl~~ ✅ Cron-entry fjernet 2026-04-30 | ~~Vil altid fejle — restarter ikke den rigtige container~~ | App |
| TLS cert renewal er ikke fuldt automatiseret | Nginx-container genstartes ikke efter `certbot.timer` → ny cert indlæses ikke | App |
| SQLite logging-DB (`data/logging/logging.sqlite3`) har ingen backup | Søgelog kan gå tabt ved disk-fejl | App |
| Discord webhook-URL hardcoded i `monitor_logs.sh` | Scriptet fejler lydløst hvis webhook ændres | App |
| ~~`auto_deploy.sh` og `cd.yml` kan konflikte~~ ✅ Cron-entry fjernet 2026-04-30 | ~~Redundant pull-restart i samme 5-minutters vindue~~ | App |
| Ingen `node_exporter` på nogen VM | Ingen host-level metrics (CPU, mem, disk) i Grafana | Begge |
| Ingen Alertmanager / alert-regler | Prometheus samler data men sender ingen alerts | Monitoring |
| Grafana kører på plain HTTP (port 3000) | Ingen TLS-fronting på Grafana UI | Monitoring |
| Ruby 3.2.3 (CI) vs. Ruby 3.2.11 (kørende image) | Minor version mismatch | App |
| ~~`whoknows.service` i `failed` state~~ ✅ Masked 2026-04-30 (unit-fil flyttet til `.disabled-2026-04-30`) | ~~Dead code — forvirrer ops~~ | App |
