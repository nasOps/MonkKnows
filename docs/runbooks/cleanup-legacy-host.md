# Cleanup: Legacy host-services på App-VM

_Oprettet: 2026-04-30 — **udført samme dag kl. ~11:23 UTC**_

> **Status:** ✅ Eksekveret 2026-04-30. `whoknows.service` er masked (unit-fil flyttet til `whoknows.service.disabled-2026-04-30`), og de to broken cron-entries er fjernet. Crontab-backup ligger i `/root/crontab-backup-2026-04-30.txt` på App-VM. Beholdt som reference + rollback-procedure.

Efter Docker-migrationen kører appen udelukkende i containere, men der var stadig pre-Docker host-services tilbage på App-VM'en. De udførte intet meningsfuldt arbejde længere, og under CD-deploy af PR #275 (2026-04-30) bidrog de målbart til en 8-minutters cold-start anomali — se "Deploy MTTR observation" i [`docs/infrastruktur/infrastructure-map.md`](../infrastruktur/infrastructure-map.md).

Denne runbook fjerner dem. Kommandoer skulle køres manuelt over SSH; intet i denne fil bliver kørt automatisk.

---

## Hvad ryddes op

| Komponent | Type | Tilstand i dag | Action |
|---|---|---|---|
| `whoknows.service` | systemd unit | Crash-looper hver 5. min (kicket af `health_check.sh`). Kører `bundle exec rackup` natively, fejler `Bundler::GemNotFound`. | Mask + slet unit-fil |
| `/opt/whoknows/scripts/health_check.sh` | cron `*/5 * * * *` | Curler `localhost:4567` på hosten — porten findes kun i Docker-netværket. Kalder `systemctl restart whoknows` ved fejl → triggerer crash-loop. | Fjern cron-entry. Script kan beholdes som reference. |
| `/opt/whoknows/scripts/auto_deploy.sh` | cron `*/5 * * * *` | `docker compose pull` hvert 5. min. Fejler stille med GHCR 401 (host mangler auth). Racer med CD-pipelinens egen SSH-deploy. | Fjern cron-entry. Script kan beholdes som reference. |
| `/usr/local/bin/monitor_logs.sh` | cron `*/5 * * * *` | Fungerer (sender Discord-alerts). Hardcoded webhook-URL — separat issue, ikke del af denne cleanup. | **Beholdes** |
| `/opt/whoknows/scripts/db_backup.sh` | cron `0 3 * * *` | Backup'er `/opt/whoknows/data/whoknows.db` (SQLite). PostgreSQL backups kommer fra Monitoring-VM. | **Beholdes** (legacy SQLite-fil bibeholdes bevidst — Nima) |

---

## Pre-checks (læs før du gør noget)

```bash
# Bekræft du er på rigtig host
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'hostname; uptime'

# Bekræft Docker-appen kører healthy
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'docker ps --format "table {{.Names}}\t{{.Status}}"'

# Bekræft https://monkknows.dk/ svarer 200
curl -sS -o /dev/null -w "HTTP %{http_code}\n" https://monkknows.dk/
```

Forventet output: `app-web-1` `Up X (healthy)`, monkknows.dk → `HTTP 200`.

**Hvis app-web-1 ikke er healthy, STOP.** Cleanup'en er ikke en nødløsning — løs container-issue først.

---

## Step 1 — Stop og mask `whoknows.service`

`disable` er ikke nok: `health_check.sh` kalder `systemctl restart whoknows`, og `restart` ignorerer `disable`. `mask` peger unit-filen til `/dev/null` så den ikke kan startes overhovedet.

**Vigtig:** Hvis unit-filen ligger som regulær fil i `/etc/systemd/system/`, fejler `mask` med "File already exists". Den skal flyttes først:

```bash
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 << 'EOF'
set -e
sudo systemctl stop whoknows.service || true
sudo systemctl disable whoknows.service || true
sudo mv /etc/systemd/system/whoknows.service /etc/systemd/system/whoknows.service.disabled-$(date +%Y-%m-%d)
sudo systemctl daemon-reload
sudo systemctl mask whoknows.service
sudo systemctl status whoknows.service --no-pager
EOF
```

Forventet output: `Loaded: masked (Reason: Unit whoknows.service is masked.)`.

---

## Step 2 — Fjern de to cron-entries

Cron'en ligger i root's crontab. Backup først, så filtrér de to linjer der refererer `health_check.sh` og `auto_deploy.sh`:

```bash
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'sudo bash -c "
set -e
crontab -l > /root/crontab-backup-$(date +%Y-%m-%d).txt
grep -vE \"health_check\\.sh|auto_deploy\\.sh\" /root/crontab-backup-$(date +%Y-%m-%d).txt | crontab -
crontab -l
"'
```

Linjer der **beholdes**:

```cron
*/5 * * * * /usr/local/bin/monitor_logs.sh >> /var/log/whoknows_monitor.log 2>&1
0   3 * * * /opt/whoknows/scripts/db_backup.sh >> /var/log/whoknows/db_backup.log 2>&1
```

---

## Step 3 — Verifikation

```bash
# Bekræft at whoknows.service ikke længere bliver kicket
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'sudo journalctl -u whoknows.service --since "10 min ago" --no-pager'

# Bekræft cron er ren
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'sudo crontab -l'

# Bekræft monkknows.dk stadig svarer
curl -sS -o /dev/null -w "HTTP %{http_code}\n" https://monkknows.dk/
```

Vent 10 minutter og tjek igen at journalctl ikke viser nye `whoknows.service`-events.

---

## Rollback

Hvis noget går galt:

```bash
# Genoptag whoknows.service (ikke anbefalet, men muligt)
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'sudo systemctl unmask whoknows.service'

# Genskab crontab fra backup
ssh -i ~/.ssh/id_rsa adminuser@4.225.161.111 'sudo crontab /tmp/crontab-backup-YYYYMMDD.txt'
```

---

## Næste skridt (separat opgave)

Når host-rod'et er væk, er det den rigtige tid til at implementere fix #1 fra "Deploy improvements"-tabellen i `infrastructure-map.md`: tilføj `healthcheck` til `docker-compose.prod.yml` + brug `up -d --wait` i CD's deploy-step. Det giver ægte fail-fast og fjerner `health_check.sh`-rollen helt.
