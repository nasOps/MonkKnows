# Whoknows – Flask → Sinatra Migration

Dette repository indeholder et legacy **Flask (Python)** projekt, som migreres gradvist til **Sinatra (Ruby)** som en del af et DevOps-/datamatikerprojekt.

Målet er at omskrive applikationen **inkrementelt**, uden at bryde eksisterende funktionalitet.

---

## Repository struktur

```text
whoknows_variations/
├── src/                # Legacy Flask-applikation
│   └── app.py
│
├── ruby-sinatra/       # Ny Sinatra-applikation
│   ├── Gemfile
│   ├── Gemfile.lock
│   ├── app.rb
│   └── vendor/         # Lokale Ruby gems (ignoreres i git)
│
├── whoknows.db         # Fælles SQLite database
├── venv/               # Python virtual environment (legacy)
└── README.md
```

---

## Teknologivalg (begrundelse)

### Runtime-miljø

**WSL (Ubuntu)** anvendes som primært udviklingsmiljø

- Matcher produktionslignende Linux-setup
- Mindre PATH- og permissions-problemer end Windows-only

### Ruby & Sinatra

**Ruby 3.2.x**

- Stabil version
- God understøttelse i gems

**Sinatra 3.x** (valgt frem for 4.x)

- Mindre opsætning
- Bedre udviklingslogs
- Matcher eksisterende dokumentation
- Fokus på migration frem for server-konfiguration

### Webserver (development)

**WEBrick**

- Simpel embedded dev-server
- Velegnet til undervisning
- Let at forklare i rapport og eksamen

---

## Setup – Ruby & Bundler (én gang pr. maskine)

### 1. Installér Ruby (WSL / Ubuntu)

```bash
sudo apt update
sudo apt install ruby-full
```

Verificér:

```bash
ruby -v
```

### 2. Installér Bundler globalt (korrekt metode)

```bash
sudo apt install ruby-bundler
```

Verificér:

```bash
bundle -v
```

**Note:**  
Bundler installeres globalt, men gems installeres lokalt pr. projekt.

---

## Setup – Sinatra-projekt

### 1. Gå til Ruby-projektet

```bash
cd ruby-sinatra
```

### 2. Initialisér Bundler

```bash
bundle init
```

Opretter `Gemfile`.

### 3. Konfigurér lokale gems (meget vigtigt)

```bash
bundle config set --local path vendor/bundle
```

**Hvorfor?**

- Undgår sudo / permissions-fejl
- Giver projekt-isolation (som Python venv)
- CI- og DevOps-venligt

### 4. Gemfile

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gem "sinatra", "~> 3.0"
gem "webrick"
```

### 5. Installér dependencies

```bash
bundle install
```

Dette opretter:

- `Gemfile.lock` (SKAL committes)
- `vendor/bundle/` (SKAL ignoreres)

### 6. .gitignore

```
ruby-sinatra/vendor/
```

---

## Start Sinatra-applikationen

### app.rb

```ruby
require "sinatra"

get "/" do
  "Sinatra says Hello World!"
end
```

### Start server (lokal udvikling)

```bash
bundle exec ruby app.rb
```

Output:

```
== Sinatra (v3.x.x) has taken the stage on 4567 ==
```

Åbn i browser:

```
http://localhost:4567
```

---

## Migration-strategi

- Flask og Sinatra kører side om side
- Samme SQLite database anvendes i starten
- Funktionalitet migreres route-for-route
- Read-only endpoints migreres først
- Auth og write-logik migreres senere

---

## DevOps-principper anvendt

- Reproducerbart setup (Gemfile.lock)
- Ingen sudo i projektet
- Klar adskillelse mellem legacy og ny kode
- Inkrementel migration (ingen big-bang rewrite)
- Dokumenterede teknologivalg

---

## Videre arbejde

- [ ] `/about` route i Sinatra
- [ ] SQLite-connection i Sinatra
- [ ] `/api/search` migration
- [ ] Sammenligning af Flask vs Sinatra request lifecycle
- [ ] Dockerisering