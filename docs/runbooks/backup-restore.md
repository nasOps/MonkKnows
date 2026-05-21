# Backup & Restore Runbook

Hvordan MonkKnows-databasen sikres, og hvordan vi henter den tilbage hvis VM2 går tabt eller data bliver ødelagt.

## Forudsætninger

Kommandoerne nedenfor bruger SSH-aliasserne `monkknows` (VM1) og `monkknows-db` (VM2). Hvis du sætter en ny maskine op, tilføj til `~/.ssh/config`:

```
Host monkknows
    HostName 4.225.161.111
    User adminuser
Host monkknows-db
    HostName 20.91.203.235
    User azureuser
```

## Hvad bliver backet up

| Hvad | Hvor | Hvornår | Retention |
|------|------|---------|-----------|
| PostgreSQL-dump (`monkknows` DB) | `/opt/monkknows-db/backups/monkknows_YYYY-MM-DD_HHMM.sql.gz` på VM2 | Dagligt kl. 03:00 dansk tid (cron på VM2) | 7 dage lokalt på VM2 |
| Offsite-kopi af samme dumps | `/opt/whoknows/backups/` på VM1 (kopieret via scp af `backup.sh`) | Samme kørsel | 7 dage lokalt på VM1 |
| Samme dumps pulled lokalt | `backups/monkknows_*.sql.gz` i repo'et | Onsdag kl. 19:00 dansk tid (cron lokalt) via `scripts/local-backup.sh` | 4 ugentlige snapshots |
| `pgdata`-volume | `monkknows-db_pgdata` Docker volume på VM2 | Live (PG's egen WAL) | — |

Dumps tages med `pg_dump` i Docker:

```bash
docker exec monkknows-db-db-1 pg_dump -U monkknows monkknows | gzip > <fil>
```

Se [`scripts/backup.sh`](../../scripts/backup.sh) for den fulde cron-kørsel (deployes til `/opt/monkknows-db/backup.sh` på VM2) og [`scripts/local-backup.sh`](../../scripts/local-backup.sh) for det lokale pull.

## Verifikation: er backups sunde?

Disse tre tjek bør køres ugentligt og før hver release.

**1. Daglige dumps er friske på VM2:**

```bash
ssh monkknows-db 'ls -lh /opt/monkknows-db/backups/ | tail -10'
```

Nyeste fil skal være under 24 timer gammel og over 500 KB (en tom dump er ~100 KB).

**2. Ugentlig lokal kopi er friskt pulled:**

```bash
ls -lh backups/
```

Skal indeholde mindst én fil fra de seneste 7 dage.

**3. Backup er faktisk genoprettelig** — kør restore-procedure mod en throwaway DB minimum én gang per måned. Se "Test-restore" nedenfor.

## Restore-procedure (production)

Brug denne hvis prod-DB er korrupt eller VM2 skal genopbygges.

> **Før du starter:** Stop app-traffik for at undgå skrivninger under restore. På VM1: `docker compose -f docker-compose.prod.yml stop web` (eller scale til 0). Web vil 502'e i restore-vinduet — det er forventet.

**1. Vælg en backup-fil.** Nyeste = `ls -t /opt/monkknows-db/backups/monkknows_*.sql.gz | head -1`.

**2. Hvis VM2 stadig kører (DB er bare korrupt):**

```bash
ssh monkknows-db
cd /opt/monkknows-db

# Drop og genskab databasen (Docker compose-container kører)
docker exec -i monkknows-db-db-1 psql -U postgres -c "DROP DATABASE IF EXISTS monkknows;"
docker exec -i monkknows-db-db-1 psql -U postgres -c "CREATE DATABASE monkknows OWNER monkknows;"

# Restore fra dump
gunzip -c backups/monkknows_<TIMESTAMP>.sql.gz | docker exec -i monkknows-db-db-1 psql -U monkknows monkknows
```

**3. Hvis VM2 er væk (genopbygning fra scratch):**

1. Provisioner en ny Ubuntu-VM i Azure med samme NSG-regler (PG 5432 åben for VM1's IP, SSH 22).
2. Installer Docker + docker compose.
3. Klon `git@github.com:nasOps/MonkKnows.git` og kopier `/opt/monkknows-db/` strukturen (compose-fil + `.env` med PG-credentials).
4. Start DB: `docker compose -f /opt/monkknows-db/docker-compose.yml up -d`
5. Kopier dump-filen (fra lokal `backups/` hvis VM2's egne er tabt) til ny VM.
6. Restore som i punkt 2 ovenfor.
7. Opdater DNS / app-config hvis IP'en er ny.

**4. Verificer restore:**

```bash
docker exec monkknows-db-db-1 psql -U monkknows monkknows -c "SELECT COUNT(*) FROM users;"
docker exec monkknows-db-db-1 psql -U monkknows monkknows -c "SELECT COUNT(*) FROM pages;"
docker exec monkknows-db-db-1 psql -U monkknows monkknows -c "SELECT MAX(created_at) FROM search_logs;"
```

Tallene bør matche dem fra før incidenten (eller fra backup-tidspunktet hvis du gendannede en gammel dump).

**5. Genstart app-traffik** på VM1 og bekræft at `/health` returnerer 200 og `/api/search?q=test` returnerer resultater.

## Test-restore (månedligt)

> **Senest verificeret: 2026-05-21** — restore af `monkknows_2026-05-21_0300.sql.gz` til `monkknows_restore_test` på VM2 leverede identiske row counts (3323 users, 51 pages, 5511 search_logs) som live DB. Backup-strategien er bevisligt genoprettelig.

Kør mod en throwaway-container — rør IKKE produktion.

```bash
# På din lokale maskine eller en sandbox-VM
docker run -d --name pg-restore-test -e POSTGRES_PASSWORD=test -p 55432:5432 postgres:16-alpine
sleep 5
docker exec pg-restore-test psql -U postgres -c "CREATE DATABASE monkknows;"

# Brug et af de lokalt-pullede dumps
gunzip -c backups/monkknows_<TIMESTAMP>.sql.gz | docker exec -i pg-restore-test psql -U postgres monkknows

# Verificer
docker exec pg-restore-test psql -U postgres monkknows -c "SELECT COUNT(*) FROM users;"

# Ryd op
docker rm -f pg-restore-test
```

Hvis restore-kommandoen fejler eller tabellerne er tomme, **er backuppen ikke brugbar** — undersøg `backup.sh` på VM2 og log-output i `/opt/monkknows-db/backups/backup.log`.

## RTO/RPO

- **RPO (data tab):** Op til 24 timer (dagligt dump). Bevidst valg — vi har ikke continuous WAL-archiving.
- **RTO (recovery time):** ~30 min hvis VM2 lever (drop + restore), ~2-4 timer hvis VM2 skal genopbygges fra scratch.

Hvis kursets SLA kræver lavere RPO, er næste skridt `pg_basebackup` + WAL-archiving til Azure Blob (out of scope for nuværende sprint).

## Kendte gaps

- Hvis både VM1 og VM2 går tabt samme dag, og det er før onsdagens lokale pull, mister vi op til en uges dumps. Mitigering: tre-stedet retention (VM2 + VM1 offsite + lokal weekly), plus tag et manuelt off-VM snapshot ved kritiske milestones.
- Restore-proceduren er ikke automatiseret — ingen `restore.sh`-script endnu. Forbedring til senere sprint.
