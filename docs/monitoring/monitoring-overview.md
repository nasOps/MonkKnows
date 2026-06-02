# Monitoring Overview

Overblik over hvad der monitoreres i MonkKnows, hvilke værktøjer der bruges, og hvad der ikke dækkes.

## Prometheus/Grafana (VM2)

Prometheus scraper hvert 15. sekund. Grafana kører på `http://20.91.203.235:3000`.

### Dashboard: MonkKnows — User Telemetry

Produktmetrikker fra appens `/metrics`-endpoint.

| Panel | Hvad |
|---|---|
| Total Registered Users | Samlet antal registrerede brugere |
| Total Searches | Samlet antal søgninger |
| Zero-Result Searches | Søgninger der returnerede 0 resultater |
| Active Users (24h) | DAU |
| Logins per Hour | Succesfulde vs. fejlede logins over tid |
| Searches per Hour | Søgninger og zero-results over tid |
| Active Users DAU/WAU/MAU | Aktive brugere de seneste 1/7/30 dage |
| Inactive Users | Brugere inaktive i 30+ dage (churn-proxy) |
| Search Result Count Distribution | p50/p95/p99 fordeling af resultater per søgning |

### Dashboard: MonkKnows — Operations

Driftsmetrikker fra app, infrastruktur og database.

| Panel | Hvad |
|---|---|
| Concurrent Requests | Antal requests in-flight lige nu |
| Total Exceptions (1h) | Exceptions i seneste time |
| Weather API Errors (1h) | Fejl mod ekstern weather API |
| 5xx Error Rate | 5xx-fejl per sekund |
| Request Rate per Endpoint | Requests/s per route |
| Concurrent Requests Over Time | In-flight requests over tid |
| Request Latency p50/p95/p99/p99.9 | Svartider fordelt på percentiler |
| Auth Endpoint Latency (p95) | Svartid for /api/login og /api/register |
| Response Size p95 per Endpoint | Svarstorrelse per route |
| Error Rate 4xx vs 5xx | Fejlrate over tid |
| Top 10 Error Classes (1h) | Hyppigste exception-typer |
| Bot/Scanner Traffic | Trafik til ukendte routes (scannere, crawlers) |
| Weather API Latency (p95) | Ekstern API-svartid (kun faktiske API-kald, ikke cache-hits) |
| Weather API Errors per Type | Fejltype fordeling |
| CPU Load (1m/5m/15m) | CPU-load pa begge VMs |
| Memory Usage (%) | RAM-forbrug pa begge VMs |
| Disk Usage / (%) | Diskforbrug pa begge VMs |
| Network I/O (bytes/s) | Netvaerkstrafik pa begge VMs |

### Prometheus-kilder

| Job | Kilde | Hvad |
|---|---|---|
| `monkknows` | `https://monkknows.dk/metrics` | App-metrikker |
| `node` (vm1) | `4.225.161.111:9100` | Host-metrikker VM1 |
| `node` (vm2) | `host.docker.internal:9100` | Host-metrikker VM2 |
| `postgres` | `postgres_exporter:9187` | PostgreSQL-metrikker |

Prometheus evaluerer desuden `rules.yml` ved hvert `evaluation_interval` (15s) — se Recording Rules nedenfor.

### Recording Rules (`rules.yml`)

Forudberegner dyre `histogram_quantile`-queries hvert 15. sekund og gemmer resultatet som færdige tidsserier. Løste et problem hvor latency-paneler tog ~84 sekunder at indlæse fordi Prometheus genberegnede over ~200 bucket-serier ved hvert datapunkt (PR #316, 2026-06-01).

| Regel | Hvad | Brugt i panel |
|---|---|---|
| `job:http_request_duration_seconds:p50/p95/p99/p999` | Samlet request-latency (alle ruter) | Operations panel #12 |
| `path:http_request_duration_seconds:p95` | Per-rute latency med `path`-label | Operations panel #13 |
| `path:app_response_size_bytes:p95` | Response-størrelse per rute | Operations panel #14 |
| `job:app_weather_api_duration_seconds:p95` | Weather API-latency | Operations panel #18 |

Navneformatet `<aggregation>:<metric>:<function>` følger Prometheus' officielle konvention for recording rules.

> [!NOTE]
> De forudberegnede serier har kun historik fra det tidspunkt `rules.yml` blev deployet. Rå `*_bucket`-data findes stadig i Prometheus hvis man vil beregne baglæns.

### Resource limits (efter PR #316)

| Service | mem_limit | cpus |
|---|---|---|
| `prometheus` | 1024m (↑ fra 256m) | 1.0 (↑ fra 0.50) |
| `postgres_exporter` | 64m | 0.10 |
| `node_exporter` | 64m | 0.10 |
| `grafana` | 384m (↑ fra 256m) | 0.50 |

Prometheus og Grafana var begge i resource-problemer: Prometheus i OOM crash-loop (54 restarts, bekræftet i `dmesg`), Grafana konstant på ~100% af sin 256m-grænse ved tunge dashboard-renders.

## Discord-alerts (VM1)

`monitor_logs.sh` korer via cron hvert 5. minut og sender Discord-alert ved fund.

- Kilde: `docker logs app-web-1`
- Matcher: `HTTP [45][0-9][0-9]`, `Error`, `error`
- Viser de seneste 20 matching linjer i Discord-beskeden

## Cron-jobs (VM1)

| Interval | Job |
|---|---|
| Hvert 5. min | `monitor_logs.sh` (Discord-alerts) |
| Dagligt kl. 03:00 | `db_backup.sh` (database-backup) |

## Lynis (VM1)

Lynis korer nightly via `lynis.timer` (systemd) og scanner host-OS'et pa VM1.

- Log: `/var/log/lynis.log`
- Rapport: `/var/log/lynis-report.dat`
- Seneste hardening index: **70/100**
- Ingen alerting eller integration med Grafana/Discord
- Manuelt opsat, ikke deployet via CD

### Aktive findings (seneste scan 2026-05-30)

| Test | Problem |
|---|---|
| KRNL-6000 | Sysctl-vaerdier afviger fra anbefalet profil |
| HRDN-7222 | Compilere (`gcc`, `cc`, `as`) er world-executable |
| HRDN-7230 | Ingen malware-scanner installeret |

## Weather API-cache

`WeatherService` cacher svar fra OpenWeatherMap i 10 minutter (`CACHE_DURATION = 600`). Cachen er in-memory og mutex-beskyttet.

Prometheus maler kun faktiske API-kald, ikke cache-hits. Det betyder:
- `app_weather_api_duration_seconds` undervurderer den reelle API-belastning hvis man sammenligner med request-raten
- Det er ikke muligt at se cache hit-rate i Grafana

## Node exporter

`node_exporter` kører på **begge** VMs og leverer CPU/RAM/disk/netværks-metrics:

- **VM2:** kører i `docker-compose.monitoring.yml` (deployes automatisk via `cd-monitoring.yml`)
- **VM1:** kører via `node_exporter.compose.yml` — deployet manuelt, ingen CD-workflow endnu

## Hvad der ikke monitoreres

- Host-niveau sikkerhedsændringer varsles ikke aktivt (Lynis logger, men sender ingen alerts)
- Lynis hardening-score eksponeres ikke til Prometheus/Grafana
- Lynis-opsætningen er ikke i CD-pipelinen og vil gå tabt hvis VM1 genoprettes
- `node_exporter` på VM1 er manuelt deployet — ikke i CD-pipelinen
