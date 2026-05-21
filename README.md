# MonkKnows

###### Sinatra Ruby
[![Ruby CI (Build & Test)](https://github.com/nasOps/MonkKnows/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nasOps/MonkKnows/actions/workflows/ci.yml) ![Ruby](https://img.shields.io/badge/ruby-3.2.3-red) ![Contributors](https://img.shields.io/github/contributors/nasOps/MonkKnows) ![Open Issues](https://img.shields.io/github/issues/nasOps/MonkKnows?label=Open%20Issues) ![Last Commit](https://img.shields.io/github/last-commit/nasOps/MonkKnows)

###### Flask Python (Legacy)
![Python](https://img.shields.io/badge/python-3.14-blue) ![Flask](https://img.shields.io/badge/flask-3.1.2-blue)

A search engine originally built in 2009, migrated from Flask (Python) to Sinatra (Ruby) as a DevOps course project. Live at **[monkknows.dk](https://monkknows.dk)**.

---

## Repository Structure
```text
MonkKnows/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
│       ├── ci.yml               # CI: lint, audit, test, smoke, e2e
│       ├── cd.yml               # CD: build → Trivy scan → push GHCR → deploy → smoke test
│       └── cd-monitoring.yml    # Deploy Prometheus + Grafana to monitoring VM
├── docs/
│   ├── branching-strategi/
│   ├── choices-and-challenges/  # ADR-log — alle væsentlige tekniske beslutninger
│   ├── openapi/
│   │   └── whoknows-spec.json   # API contract (source of truth — Anders)
│   ├── runbooks/
│   └── specs/
│       └── ruby-sinatra-spec.json   # Implementation artifact — documents our extensions beyond the contract
├── legacy-flask/                # Python/Flask legacy application
│   └── generated-flasgger-spec.json
├── monitoring/                  # Prometheus + Grafana config
│   ├── docker-compose.monitoring.yml
│   └── prometheus.yml
├── ruby-sinatra/                # Active Ruby/Sinatra application
├── scripts/                     # Ops scripts (backup, migration, hooks)
├── docker-compose.dev.yml       # PostgreSQL + app + Guard hot-reload
├── docker-compose.prod.yml      # Production: GHCR image + Nginx
└── nginx.conf                   # Reverse proxy, TLS, security headers
```

---

## Stack

| Layer | Technology |
|---|---|
| Application | Ruby 3.2.3, Sinatra ~> 4.0, Puma |
| Database | PostgreSQL 16 (primary) + SQLite (search logging) |
| Auth | bcrypt ~> 3.1 |
| Observability | Prometheus + Grafana |
| Infra | Docker, Nginx, Azure VMs |
| CI/CD | GitHub Actions (`ci.yml` + `cd.yml`) |

---

## Setup

### Docker (recommended)
```bash
docker compose -f docker-compose.dev.yml up
```

App runs on `http://localhost:4567` with hot-reload via Guard.

### Local (Ruby)
```bash
cd ruby-sinatra
bundle config set --local path vendor/bundle
bundle install
bundle exec rackup config.ru -p 4567
```

### Python / Flask (Legacy)
```bash
cd legacy-flask
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

App runs on `http://localhost:5000`

---

## CI/CD

**CI** (`ci.yml`) runs on every push/PR to `main`:
- Bundler Audit (CVE scan), Brakeman (static analysis), Hadolint (Dockerfile lint)
- RSpec with SimpleCov (60% min coverage), Docker smoke test, Playwright E2E

**CD** (`cd.yml`) runs on push to `main`:
1. Build Docker image → Trivy vulnerability scan → push to GHCR
2. SSH deploy to production VM → `docker compose up --wait`
3. Smoke test against `https://monkknows.dk`

---

## Production

Live at **https://monkknows.dk** on Azure (Ubuntu 22.04).

Two VMs:
- **App VM** — Nginx + Sinatra container (`ghcr.io/nasops/monkknows:latest`)
- **Monitoring VM** — Prometheus, Grafana, PostgreSQL 16
