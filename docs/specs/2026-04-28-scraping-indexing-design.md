# Scraping & Indexing Design

**Date:** 2026-04-28
**Authors:** Sofie
**Status:** Implemented
**Related issues:** #272, #204

---

## Summary

Implementerer web-crawling og indeksering af sider baseret på loggede søgninger. En Azure Function (Python) scraper relevante websites med BeautifulSoup4 og batch-poster indholdet til appens REST API, som upsert'er det i PostgreSQL. Søge-endpointet returnerer allerede resultater fra `pages`-tabellen via PostgreSQL full-text search (tsvector).

---

## Arkitektur

```text
[Bruger]
    │
    ▼ GET /api/search?q=ruby
[Sinatra App — VM1]
    │ INSERT search_logs
    ▼
[PostgreSQL — VM2: search_logs]

─────────────────────────── Crawler flow ───────────────────────────

[Azure Function — monkknows-crawler]
    │ Manuel: HTTP POST /api/crawl
    │ Schedule: timer trigger (søndag 02:00 UTC) — aktiveres ved behov
    │
    ├─ 1. GET /api/search-logs/top?limit=10
    │       ↓ [Sinatra App — VM1]
    │       ↓ top søgetermer fra search_logs
    │
    ├─ 2. requests + BeautifulSoup4
    │       ↓ seed URLs + Wikipedia URLs baseret på søgetermer
    │       ↓ scraper title, content, language
    │
    └─ 3. POST /api/pages  {"pages": [...]}
            ↓ [Sinatra App — VM1]
            ↓ Page.upsert_all (title som PK — ingen duplikater)
            ▼
    [PostgreSQL — VM2: pages + tsv trigger]

─────────────────────────── Søgning ────────────────────────────────

[Bruger]
    │
    ▼ GET /api/search?q=ruby
[Sinatra App — VM1]
    │ Page.search_tsvector(query, language)
    ▼
[Resultater fra indekserede sider]
```

---

## Komponenter

### Nye API-endpoints (ruby-sinatra/app.rb)

#### `GET /api/search-logs/top`

Returnerer top-N søgetermer fra `search_logs`, sorteret efter antal søgninger.

| Parameter | Type | Default | Max |
|-----------|------|---------|-----|
| `limit` | integer | 10 | 50 |

Respons:
```json
{ "data": ["ruby", "postgresql", "docker"] }
```

Ingen autentifikation — data er aggregerede søgetermer uden PII.

#### `POST /api/pages`

Batch-upsert af scrapede sider i `pages`-tabellen.

Autentifikation: `Authorization: Bearer <CRAWLER_API_KEY>` (påkrævet hvis `CRAWLER_API_KEY` er sat i miljøet).

Request body:
```json
{
  "pages": [
    {
      "title": "Ruby (programming language)",
      "url": "https://en.wikipedia.org/wiki/Ruby_(programming_language)",
      "language": "en",
      "content": "Ruby is a dynamic, open source programming language..."
    }
  ]
}
```

Respons:
```json
{ "inserted": 8 }
```

Upsert-strategi: `Page.upsert_all(records, unique_by: :title)` — title er primærnøgle i `pages`-tabellen. Crawleren kan køres gentagne gange uden duplikater.

### Azure Function (azure-function/)

```text
azure-function/
├── function_app.py     ← timer trigger + HTTP trigger + crawler logik
├── requirements.txt    ← azure-functions, requests, beautifulsoup4, lxml
└── host.json           ← Azure Functions v2 config
```

**Timer trigger:** `0 0 2 * * 0` (søndag 02:00 UTC) — `run_on_startup=False`, aktiveres ved at sætte schedule i produktion.

**HTTP trigger:** `POST /api/crawl` — manuel invokation via Azure Portal eller curl.

**Crawler-logik:**
1. Henter top søgetermer fra `GET /api/search-logs/top`
2. Bygger Wikipedia-URLs fra søgetermerne + seed-liste
3. Scraper hver URL med `requests` + `BeautifulSoup4` (lxml parser)
4. Ekstraherer title (`#firstHeading` på Wikipedia, ellers `<title>`), content (`.mw-parser-output`, ellers `<main>/<article>/<body>`), language (`<html lang="...">` attribut)
5. Batch-poster til `POST /api/pages`

**Seed URLs (fallback når search_logs er tom):**
- Ruby, PostgreSQL, Docker, DevOps, Copenhagen, Danmark (da), Sinatra, Nginx

**Sprog:** Understøtter `en`, `da`, `de`, `fr`, `es` — matcher `Page::PG_TEXT_SEARCH_CONFIG` i app.rb.

**Content-begrænsning:** Max 50.000 tegn pr. side.

### GitHub Actions Deploy (`.github/workflows/deploy-crawler.yml`)

Deployer Azure Function ved push til `main` når filer i `azure-function/**` ændres, samt ved `workflow_dispatch`.

```yaml
on:
  push:
    branches: [main]
    paths:
      - azure-function/**
  workflow_dispatch:
```

---

## Miljøvariabler

### Azure Function (Application Settings på Function App)

| Navn | Beskrivelse |
|------|-------------|
| `APP_URL` | URL til Sinatra-appen, f.eks. `https://monkknows.dk` |
| `CRAWLER_API_KEY` | Delt hemmelighed — beskytter `POST /api/pages` |

### Sinatra App (.env / CD-pipeline)

| Navn | Beskrivelse |
|------|-------------|
| `CRAWLER_API_KEY` | Samme nøgle som Azure Function — valideres i `POST /api/pages` |

### GitHub Secrets (deploy-crawler.yml)

| Navn | Beskrivelse |
|------|-------------|
| `AZURE_FUNCTIONAPP_NAME` | Navn på Azure Function App, f.eks. `monkknows-crawler` |
| `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` | Publish profile hentet fra Azure Portal |

---

## Database

`pages`-tabellen eksisterede allerede fra PostgreSQL-migrationen (issue #200–203). Crawleren tilføjer/opdaterer rækker — ingen ny migration nødvendig.

| Kolonne | Type | Bemærkning |
|---------|------|------------|
| `title` | text (PK) | Primærnøgle — bruges som upsert-nøgle |
| `url` | text NOT NULL | Sidens URL |
| `language` | text NOT NULL | ISO-sprogkode, default `en` |
| `content` | text NOT NULL | Ren tekst (HTML-tags fjernet) |
| `last_updated` | datetime | Sættes til `Time.now` ved hvert upsert |
| `tsv` | tsvector | Auto-opdateres af PostgreSQL-trigger ved INSERT/UPDATE |

PostgreSQL-triggeren (`pages_tsv_update`) opdaterer automatisk `tsv`-kolonnen fra `title + content` med korrekt sprogkonfiguration — crawleren behøver ikke håndtere dette.

---

## Skalerbarhed

Crawleren er designet til at skalere uden kodeændringer:

- **Mere data:** Tilføj URLs til `SEED_URLS` i `function_app.py` eller øg `limit` i `_fetch_top_search_terms()`
- **Automatisk schedule:** Uncomment `schedule` i `function_app.py` og sæt `run_on_startup=False`
- **Hyppigere crawl:** Justér cron-udtryk (`0 0 2 * * 0` → `0 0 2 * * *` for daglig)
- **Afkobling:** Crawleren kommunikerer udelukkende via REST API — databaselaget kan udskiftes uden at røre crawleren

Flex Consumption-planen (Azure) skalerer til nul når crawleren ikke kører — vi betaler kun for faktisk køretid.
