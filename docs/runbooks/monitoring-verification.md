# Monitoring Verification Runbook

Tjekliste til at verificere at server-telemetri og log-indsamling virker. Kør før hver release og efter VM-restarts.

## Hurtigt sundhedstjek (5 min)

**1. Prometheus targets er UP:**

Åbn `http://20.91.203.235:9090/targets` (eller via SSH tunnel). Alle jobs bør være "UP":

- `monkknows` (app-metrics fra `https://monkknows.dk/metrics`)
- `node` på vm1 (4.225.161.111:9100) og vm2 (host.docker.internal:9100)
- `postgres` (postgres_exporter:9187) — *nyt fra denne sprint, kræver deploy*

Hvis et target er DOWN, læs "fejl-tjek" nedenfor.

**2. Grafana dashboards loader data:**

Åbn `http://20.91.203.235:3000` → User Telemetry dashboard. Alle paneler bør vise data for de seneste 5 min. Hvis paneler er tomme:
- Tjek tidsvindue (skift til "Last 15 minutes")
- Tjek at Prometheus datasource peger på `http://prometheus:9090`

**3. Log-pipeline virker:**

```bash
ssh monkknows 'docker logs --tail 20 app-web-1'
ssh monkknows 'docker logs --tail 20 app-nginx-1'
ssh monkknows 'journalctl --since "5 minutes ago" -u docker'
```

Forvent: app-logs viser HTTP requests, nginx-logs viser proxy traffic, journalctl er stille (ingen fejl).

**4. Strukturerede app-logs skrives til DB:**

```bash
ssh monkknows-db 'docker exec monkknows-db-db-1 psql -U monkknows monkknows -c "SELECT COUNT(*), MAX(created_at) FROM search_logs WHERE created_at > NOW() - INTERVAL '\''1 hour'\'';"'
```

Forvent: COUNT > 0 hvis nogen har søgt i den sidste time. MAX skal være indenfor 5 min af nu.

**5. Discord-alerting virker (cron-baseret):**

```bash
ssh monkknows 'tail -20 /var/log/monitor_logs.log'
```

Forvent: `LAST_CHECK` opdateres hvert 5. minut. Ingen "webhook failed"-linjer.

## Fejl-tjek

| Symptom | Mulig årsag | Action |
|---------|-------------|--------|
| Prometheus `monkknows` target DOWN | Nginx blokerer Prometheus' IP (efter `/metrics`-hardening i denne sprint), eller app er nede | Tjek `/metrics`-allow-listen i `nginx.conf` matcher VM2's IP (20.91.203.235). Curl fra VM2: `curl -I https://monkknows.dk/metrics` |
| Prometheus `node` vm1 DOWN | Azure NSG blokerer eller node_exporter er stoppet | `ssh monkknows 'docker ps | grep node-exporter'` og `curl 4.225.161.111:9100/metrics` fra VM2 |
| Prometheus `postgres` DOWN | Exporter-container mangler env-vars eller user mangler i DB | Se "Deploy postgres_exporter" nedenfor |
| Grafana panel tomt for >5 min | Prometheus scraper ikke, eller dashboard-query er forkert | Verificer Prometheus targets først; ellers redigér panel og test query i Prometheus UI |
| Ingen logs i `search_logs` | App fejler tavst, eller DB er nede | `ssh monkknows 'docker logs --tail 50 app-web-1'` — kig efter exceptions |

## Alerting-thresholds (review)

Det vi har:

- **Discord webhook** ved 4xx/5xx i `docker logs app-web-1` (cron hver 5 min). Threshold: minimum 1 fejl-linje i seneste interval → alert.
- **Trivy CI gate** ved CRITICAL CVE i Docker-images → blokerer merge.
- **Smoke-tests** i `cd.yml` mod `/health` efter deploy → fejler deploy hvis ikke 200.

Det vi IKKE har (bevidst, jf. course "do not overengineer"):

- Alertmanager eller Grafana alert rules — ingen metric-based alerts (kursus markerer Highly Optional).
- PagerDuty / on-call rotation — ikke relevant for student-projekt.

**Forslag til thresholds hvis vi udvider:** App-latens p95 > 1s i 5 min, CPU > 80% i 10 min, disk free < 10%, PG connections > 80% af `max_connections`.

## Deploy postgres_exporter (eengangs-setup)

Denne sprint tilføjede `postgres_exporter`-service til `monitoring/docker-compose.monitoring.yml`. For at deploye:

**1. Opret read-only PG-user på VM2:**

```bash
ssh monkknows-db
docker exec -it monkknows-db-db-1 psql -U postgres monkknows <<'SQL'
CREATE USER postgres_exporter WITH PASSWORD '<choose-strong-password>';
GRANT pg_monitor TO postgres_exporter;
SQL
```

**2. Tilføj credentials til VM2's monitoring `.env`:**

```bash
ssh monkknows-db
cd /opt/monkknows-monitoring/  # eller hvor compose-stacken kører
echo 'POSTGRES_EXPORTER_USER=postgres_exporter' >> .env
echo 'POSTGRES_EXPORTER_PASSWORD=<same-as-above>' >> .env
```

**3. Pull repo-ændringerne og restart stack:**

```bash
git pull origin main
docker compose -f docker-compose.monitoring.yml up -d postgres_exporter
docker compose -f docker-compose.monitoring.yml restart prometheus
```

**4. Verificer:**

```bash
curl http://localhost:9187/metrics | head -20  # bør vise pg_* metrics
```

Åbn Prometheus UI → Targets → `postgres` job skal vise UP.

## Kendte gaps (op til oral exam)

- **Ingen central log-aggregation** (Loki/ELK). Logs spredt over PG-tabeller, container stdout, journalctl, Discord-alert. Bevidst valg — kursus siger "do not overengineer".
- **`monitor_logs.sh` findes kun på VM1**, ikke i repo'et. Hvis VM1 genopbygges er alerting-scriptet tabt. TODO: kopier til `scripts/monitor_logs.sh` og lad CD installere det.
- **`monitor_logs.sh` scraper kun `app-web-1`** — ikke nginx, ikke PG, ikke journalctl. Udvidelse er noteret som follow-up.
- **Ingen metric-based alerting.** Se "Alerting-thresholds" ovenfor.
