# Deployment Strategy

## Vores nuværende setup

Applikationen kører på to Azure-virtuelle maskiner:

**VM1 (app): 4.225.161.111**
- 1 vCPU (Intel Xeon Platinum 8370C @ 2.80GHz)
- 847 MB RAM (ca. 116 MB tilgængeligt under drift)
- Ingen swap konfigureret
- To Docker-containere kører parallelt: `nginx` og `web`

**VM2 (db + monitoring): 20.91.203.235**
- PostgreSQL 16 i Docker
- Prometheus + Grafana + node_exporter

**Applikationsstack på VM1:**
- `web`: `ghcr.io/nasops/monkknows:latest` (Ruby 3.2 / Sinatra 4.0 via Puma), 256 MB RAM-limit, 0.5 CPU
- `nginx`: `nginx:alpine` som reverse proxy, TLS via Let's Encrypt, 128 MB RAM-limit, 0.25 CPU
- Styret af `docker-compose.prod.yml`

**CD-pipeline (GitHub Actions):**
1. Push til `main` trigger CD
2. Docker image bygges, Trivy-scannes og pushes til GHCR
3. GitHub Actions SSH'er ind på VM1 og kører:
   ```
   docker compose -f docker-compose.prod.yml pull
   docker compose -f docker-compose.prod.yml up -d --remove-orphans --wait --wait-timeout 600
   ```
4. `--wait` blokerer pipelinen indtil healthchecket på `/health` rapporterer healthy
5. Smoke test bekræfter at `https://monkknows.dk` svarer med HTTP 200

---

## Vores problem

`docker compose up -d` stopper den kørende container og starter en ny. Der er kun én instans af `web`-containeren, og der er ingen overlap mellem gammel og ny container. Det betyder, at applikationen er utilgængelig i det tidsrum, det tager den nye container at starte op og bestå sit healthcheck.

Derudover har VM1 kun 1 vCPU og 847 MB RAM uden swap, hvilket begrænser mulighederne for at køre to web-containere parallelt under en deployment.

---

## Deployment-strategier

| Strategi | Kort beskrivelse |
|---|---|
| **Blue-Green** | To identiske miljøer, kun et er live. Nul downtime, nem rollback. Kræver dobbelt infrastruktur. |
| **Canary** | Ny version rulles ud til en lille andel brugere først. Observeres, så rulles resten ud. |
| **Cluster Immune System** | Udvidelse af canary med automatisk rollback ved fejlende health checks. |
| **Rolling updates** | Infrastruktur opdateres gradvist, en instans ad gangen. |
| **Ramped** | Som rolling, men med stigende procentdel af servere per iteration. |

---

## Vores valg