# PostgreSQL Migration Design

**Date:** 2026-04-14
**Authors:** Andreas
**Status:** Draft
**Related issues:** #200, #201, #202, #203, #204

---

## Summary

Migrate MonkKnows from SQLite to PostgreSQL on a dedicated Azure VM, replacing FTS5 full-text search with PostgreSQL's native tsvector. The cutover uses a blue-green strategy with automated rollback.

## Decisions Made (GitHub Discussions)

These decisions were made collaboratively via GitHub Discussions with voting:

| Decision | Discussion | Result | Rationale |
|----------|-----------|--------|-----------|
| Database engine | #226 | PostgreSQL | Best fit for relational data, ACID guarantees for auth, built-in FTS via tsvector, better concurrent writes than MySQL |
| ORM | #228 | Keep ActiveRecord | Pragmatic — rewriting to raw SQL has real cost with zero functional gain. Acknowledged as technically suboptimal for two simple tables |
| Migration tool | #229 | Rake migrations | Already set up, integrated with ActiveRecord. Flyway's JVM dependency too heavy for our VM |
| Scraping tool | #230 | Nokogiri + HTTParty | Simplest tool that solves the problem. Ferrum as upgrade path if JS-heavy sites needed |

---

## 1. Infrastructure

### Current state

```
VM1 (Azure) — 4.225.161.111
├── nginx container (128MB, 0.25 CPU)
├── web container (256MB, 0.50 CPU)
└── SQLite file: /opt/whoknows/data/whoknows.db
```

### Target state

```
VM1 (Azure) — existing
├── nginx container
├── web container (connects to VM2 via DATABASE_URL)
└── SQLite file preserved as rollback

VM2 (Azure free tier) — new, dedicated database server
├── PostgreSQL 16 container
├── Persistent volume: /var/lib/postgresql/data
└── Firewall: only VM1 IP on port 5432
```

### Why a separate VM?

- **Resource isolation:** PostgreSQL memory usage won't compete with the app
- **Cost:** Azure free tier covers a second VM at no cost
- **Assignment requirement:** "Database should not be co-located unless justified"
- **Scalability:** Database can be independently scaled or replaced with managed service later
- **Security:** Smaller attack surface — DB port only open to app server

### Security

- Azure NSG: restrict port 5432 to VM1's IP only
- PostgreSQL `pg_hba.conf`: app user from VM1's IP only
- Credentials stored in GitHub Secrets, injected via CD pipeline
- No hardcoded credentials anywhere

---

## 2. Code Changes

### database.yml

```yaml
development:
  adapter: postgresql
  host: db                    # Docker service name
  database: monkknows_dev
  username: monkknows
  password: dev_password
  pool: 5

production:
  adapter: postgresql
  host: <%= ENV['DB_HOST'] %>
  database: <%= ENV.fetch('DB_NAME', 'monkknows') %>
  username: <%= ENV['DB_USER'] %>
  password: <%= ENV['DB_PASSWORD'] %>
  pool: 5

test:
  adapter: sqlite3
  database: ":memory:"
  pool: 5
  timeout: 5000
```

Test environment stays on SQLite in-memory for speed. This is a deliberate trade-off: test speed vs. prod parity. ActiveRecord abstracts the difference for model tests. E2E tests will use PostgreSQL via Docker.

### Gemfile changes

```ruby
gem 'pg', '~> 1.5'                              # PostgreSQL adapter
gem 'sqlite3', '~> 1.6', groups: [:test]         # Only needed for unit tests
```

### Search: FTS5 to tsvector

This is the largest code change. SQLite FTS5 and PostgreSQL tsvector have fundamentally different syntax.

**Current (SQLite FTS5):**
```ruby
Page.joins('INNER JOIN pages_fts ON pages.rowid = pages_fts.rowid')
    .where(language: language)
    .where('pages_fts MATCH ?', sanitized_q)
    .order(Arel.sql('pages_fts.rank'))
```

**Target (PostgreSQL tsvector):**
```ruby
Page.where(language: language)
    .where("tsv @@ plainto_tsquery('english', ?)", q)
    .order(Arel.sql("ts_rank(tsv, plainto_tsquery('english', ?))"), q)
```

Key differences:
- No separate virtual table — tsvector is a column on `pages`
- No `sanitize_fts5` needed — `plainto_tsquery` handles special characters natively
- Ranking built into `ts_rank()` function
- Language parameter maps to PostgreSQL text search configurations

**Migration to create tsvector:**
```sql
ALTER TABLE pages ADD COLUMN tsv tsvector;
UPDATE pages SET tsv = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(content,''));
CREATE INDEX idx_pages_tsv ON pages USING GIN(tsv);

-- Auto-update trigger
CREATE TRIGGER pages_tsv_update BEFORE INSERT OR UPDATE ON pages
FOR EACH ROW EXECUTE FUNCTION
  tsvector_update_trigger(tsv, 'pg_catalog.english', title, content);
```

### docker-compose.dev.yml

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: monkknows_dev
      POSTGRES_USER: monkknows
      POSTGRES_PASSWORD: dev_password
    ports:
      - "5432:5432"

  web:
    build:
      context: ./ruby-sinatra
      target: build
    ports:
      - "4567:4567"
    volumes:
      - ./ruby-sinatra:/app
    depends_on:
      db:
        condition: service_healthy
    environment:
      - RACK_ENV=development
      - DB_HOST=db
      - DB_USER=monkknows
      - DB_PASSWORD=dev_password
      - DB_NAME=monkknows_dev
    command: sh -c "bundle exec rake db:migrate && ruby app.rb & bundle exec guard --no-interactions --no-bundler-warning"

volumes:
  pgdata:
```

### docker-compose.prod.yml

```yaml
services:
  nginx:
    # ... unchanged ...

  web:
    image: ghcr.io/nasops/monkknows:latest
    mem_limit: 256m
    cpus: 0.50
    environment:
      - RACK_ENV=production
      - DB_HOST=${DB_HOST}
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_NAME=${DB_NAME}
      - SESSION_SECRET=${SESSION_SECRET}
      - OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
    restart: unless-stopped
```

Note: SQLite volume mount removed. No more file-based database in production.

---

## 3. Data Migration

### What needs to be migrated

| Table | Estimated rows | Notes |
|-------|---------------|-------|
| `users` | ~50 | Preserve id, password_digest, force_password_reset. Some users have MD5 `password` field (gradual migration) |
| `pages` | ~thousands | Preserve all fields. Generate tsvector column after insert |

### Migration script: `scripts/migrate_sqlite_to_pg.rb`

1. Connect to SQLite file on VM1
2. Connect to PostgreSQL on VM2
3. Read all `users` rows, bulk insert into PostgreSQL (preserving IDs and all password fields)
4. Read all `pages` rows, bulk insert into PostgreSQL
5. Generate tsvector column from title + content
6. Create GIN index and auto-update trigger
7. Verify row counts match
8. Log last migrated user ID for delta-sync

### Delta-sync for cutover

**Challenge:** Between the initial migration and cutover, new users may register in SQLite. These would be lost.

**Solution:** The cutover script runs a final delta-sync:
```ruby
last_migrated_id = pg_conn.exec("SELECT MAX(id) FROM users").first['max'].to_i
new_users = sqlite_conn.execute("SELECT * FROM users WHERE id > ?", last_migrated_id)
# Insert new_users into PostgreSQL
```

This is run during the brief maintenance window (~30 seconds) when the app is frozen.

---

## 4. Automated Blue-Green Cutover

The cutover is treated as a deployment — same principles as our CI/CD pipeline: automated, observable, with rollback.

### scripts/cutover_to_pg.sh

```
Phase 1: PRE-FLIGHT
  ├── Verify PostgreSQL is reachable from VM1
  ├── Verify row counts match (within expected delta)
  └── Verify app is healthy before starting

Phase 2: FREEZE (maintenance mode)
  ├── Set MAINTENANCE_MODE=true in app env
  ├── App returns 503 on all write endpoints
  └── Read endpoints still work (search, weather)

Phase 3: FINAL SYNC
  ├── Run delta-sync (users WHERE id > last_migrated)
  ├── Verify final row counts match exactly
  └── Log sync results

Phase 4: CUTOVER
  ├── Update .env on VM1 with DB_HOST, DB_USER, DB_PASSWORD
  ├── docker compose pull && up -d
  └── Wait for health check to pass

Phase 5: VERIFY
  ├── Smoke test: GET /health (200?)
  ├── Smoke test: GET /api/search?q=test (200, results?)
  ├── Smoke test: POST /api/login with test user (422 expected)
  └── Check logs for errors

Phase 6: RESULT
  ├── If all checks pass → remove maintenance mode, done
  └── If any check fails → ROLLBACK (see below)

ROLLBACK:
  ├── Restore old .env (SQLite config)
  ├── docker compose up -d
  ├── Verify app works on SQLite
  └── Alert team
```

### Why this approach?

- **Automated:** One script, no manual steps during cutover
- **Observable:** Every phase logs its result
- **Reversible:** SQLite file still on VM1, rollback is an env var swap + redeploy
- **Repeatable:** Can be dry-run tested before the actual cutover
- **Minimal downtime:** Only write endpoints are affected during freeze (~30 sec)

---

## 5. CI/CD Pipeline Changes

### CI (ci.yml)

- **Unit tests:** Stay on SQLite in-memory (fast, no external deps)
- **E2E tests:** Switch to PostgreSQL via docker-compose in CI
- **New step:** Run tsvector search test to verify FTS works

### CD (cd.yml)

- **New secrets:** `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- **Transfer .env:** Include database credentials
- **Post-deploy:** Run `rake db:migrate` on the container after deploy (handles schema changes)

### Smoke test

Unchanged — still checks `https://monkknows.dk` returns 200.

---

## 6. Rollback Plan

At every stage, rollback is possible:

| Stage | Rollback |
|-------|----------|
| VM2 setup | Delete VM2, no impact on app |
| Code changes (PR) | Don't merge, revert branch |
| Data migration | Drop PostgreSQL tables, re-run script |
| After cutover | Swap env vars back to SQLite, redeploy |

SQLite file is preserved on VM1 indefinitely as insurance.

---

## 7. Branching Strategy

### Exception to trunk-based development

This migration uses an **integration branch** pattern — a deliberate exception to our trunk-based workflow.

**Why:** A database migration cannot be deployed incrementally. Half-SQLite, half-PostgreSQL makes no sense in production. The integration branch lets us develop, test and verify the full migration before it touches `main`.

**How:** Rebase `main` onto the integration branch as needed to stay current.

```
main (production — stays on SQLite until migration is verified)
  └── 203-devops-postgresql-migration (integration branch)
        ├── 203-db-postgresql-setup         (Gemfile, database.yml, pg gem)
        ├── 203-db-fts5-to-tsvector         (search logic, tsvector migration)
        ├── 203-db-docker-dev-postgres      (docker-compose.dev.yml with PG)
        ├── 203-db-data-migration-script    (SQLite → PG script + delta-sync)
        ├── 203-db-cutover-script           (automated blue-green cutover)
        └── 203-db-cd-pipeline-update       (secrets, env vars in CD)
```

**Merge flow:**
1. Sub-branches are created from `203-devops-postgresql-migration`
2. Sub-branches merge back into `203-devops-postgresql-migration` via PR (review + CI)
3. When all sub-branches are merged and tested, `203-devops-postgresql-migration` merges into `main` via one final PR
4. This final PR triggers CD → production deploys with PostgreSQL

**Choices and Challenges documentation:** Why we chose an integration branch for this specific task despite running trunk-based development. The migration is atomic by nature — it either works fully or not at all.

---

## 8. Task Breakdown and Assignment

| # | Task | Branch | Dependency | Status |
|---|------|--------|------------|--------|
| 1 | Provision VM2, install Docker, run PostgreSQL container | (infra, no branch) | — | done |
| 2 | Firewall: NSG + pg_hba.conf lockdown | (infra, no branch) | 1 | done |
| 3 | Code: database.yml, Gemfile (pg gem) | `203-db-postgresql-setup` | — | |
| 4 | Code: FTS5 → tsvector search logic in Page model + app.rb | `203-db-fts5-to-tsvector` | 3 | |
| 5 | Rake migration: create tsvector column, GIN index, trigger | `203-db-fts5-to-tsvector` | 3 | |
| 6 | docker-compose.dev.yml PostgreSQL setup | `203-db-docker-dev-postgres` | 3 | |
| 7 | Data migration script (SQLite → PostgreSQL + delta-sync) | `203-db-data-migration-script` | 1, 3 | |
| 8 | Automated cutover script with rollback | `203-db-cutover-script` | 7 | |
| 9 | Update CD pipeline (new secrets, env vars) | `203-db-cd-pipeline-update` | 3 | |
| 10 | E2E tests against PostgreSQL in CI | `203-db-cd-pipeline-update` | 4, 6 | |
| 11 | Choices and Challenges documentation | (in each sub-branch) | — | |
| 12 | Blue-green cutover in production | Final PR to `main` | All above | |

---

## 9. Choices and Challenges Documentation

Each of these should be documented as a section in `docs/choices-and-challenges/Choices and Challenges.md`:

1. **Database Engine Choice** — PostgreSQL over MySQL/NoSQL. Reference Discussion #226
2. **ORM Decision** — Keep ActiveRecord despite instructor feedback. Pragmatic vs. technically correct. Reference Discussion #228
3. **Migration Tool** — Rake over Flyway. JVM dependency concern. Reference Discussion #229
4. **Database Placement** — Separate VM over co-located or managed service. Cost, isolation, assignment requirements
5. **FTS5 → tsvector** — Why native PostgreSQL FTS replaces SQLite virtual tables. Removes sanitize_fts5 hack
6. **Blue-Green Cutover** — Treating DB migration as a deployment. Automated script with rollback
7. **Data Integrity During Migration** — Delta-sync + maintenance mode to prevent data loss
8. **Dev Environment** — PostgreSQL in Docker for dev parity with production. Trade-off: heavier local setup vs. consistency
9. **Integration Branch** — Exception to trunk-based for atomic migration. Why incremental deploy wasn't possible
10. **Cost: Self-hosted vs. Managed Service** — Azure free tier VM vs. Supabase/Neon. Chose self-hosted for cost (free), full control and no vendor lock-in. Trade-off: more ops overhead
11. **Test Strategy During Migration** — Unit tests stay on SQLite in-memory for speed, E2E tests switch to PostgreSQL. Trade-off: test speed vs. production parity. ActiveRecord abstracts most differences, but FTS is tested via E2E

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| PostgreSQL tsvector gives different search results than FTS5 | Users notice changed rankings | Test with real queries before cutover |
| MD5 password users can't login after migration | Users locked out | Preserve both `password` and `password_digest` columns |
| VM2 goes down | App can't reach database | Monitor VM2, SQLite fallback documented |
| Data lost during cutover window | New registrations disappear | Maintenance mode + delta-sync |
| `pg` gem adds build complexity to Docker image | CI/build breaks | Test Dockerfile build in CI before merge |
