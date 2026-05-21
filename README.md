# MonkKnows

###### Sinatra Ruby
[![Ruby CI (Build & Test)](https://github.com/nasOps/MonkKnows/actions/workflows/ci.yaml/badge.svg?branch=development)](https://github.com/nasOps/MonkKnows/actions/workflows/ci.yaml) ![Ruby](https://img.shields.io/badge/ruby-3.2.8-red) ![Contributors](https://img.shields.io/github/contributors/nasOps/MonkKnows) ![Open Issues](https://img.shields.io/github/issues/nasOps/MonkKnows?label=Open%20Issues) ![Last Commit](https://img.shields.io/github/last-commit/nasOps/MonkKnows)

###### Flask Python (Legacy)
![Python](https://img.shields.io/badge/python-3.14-blue) ![Flask](https://img.shields.io/badge/flask-3.1.2-blue)

A search engine originally built in 2009, currently being migrated from Flask (Python) to Sinatra (Ruby) as part of a DevOps project.



---

## Repository Structure
```text
MonkKnows/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
├── docs/
│   ├── branching-strategi/
│   ├── choices-and-challenges/
│   ├── openapi/
│   │   └── whoknows-spec.json       # API contract (source of truth — Anders)
│   ├── runbooks/
│   └── specs/
│       └── ruby-sinatra-spec.json   # Implementation artifact — documents our extensions beyond the contract
├── legacy-flask/
│   └── generated-flasgger-spec.json # Auto-generated spec from legacy Flask app
├── monitoring/                      # Prometheus + Grafana config
├── ruby-sinatra/                    # Active Ruby/Sinatra application
└── scripts/
```

---

## Migration Strategy

Flask and Sinatra run side by side during migration. Functionality is moved route by route – read-only endpoints first, authentication and write logic later. Both versions share the same SQLite database in the interim.

---

## Setup

### Ruby / Sinatra
```bash
cd ruby-sinatra
bundle config set --local path vendor/bundle
bundle install
bundle exec ruby app.rb
```

App runs on `http://localhost:4567`

### Python / Flask (Legacy)
```bash
cd python-legacy
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python app.py
```

App runs on `http://localhost:5000`