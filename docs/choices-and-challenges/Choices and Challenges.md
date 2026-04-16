# Choices and Challenges

**Written by:** Andreas, Nima & Sofie
 **Updated:** 7th April 2026

------

## Ruby Version Management

### Context

Ved migration fra Python til Ruby/Sinatra havde teamet behov for at vælge en stabil Ruby version. Der eksisterer forskellige Ruby versioner (3.x.x og 4.x.x), hvor version 4 er nyere men mindre stabil.

### Challenge

- Ruby 4.x.x er nyere men har kompatibilitetsproblemer med Sinatra
- Teammedlemmer havde forskellige Ruby versioner installeret lokalt
- Nogle gems i version 4 ligger paradoksalt under version 3 i versionsnummerering
- Risiko for inkonsistens mellem udviklingsmiljøer

### Choice

**Beslutning:** Standardisere på Ruby 3.x.x for alle teammedlemmer

**Hvordan valget blev truffet:**

- Prioriterede stabilitet over nyeste features
- Sinatra kompatibilitet var afgørende
- Konsistens mellem udviklingsmiljøer var kritisk

**Fordele:**

- Stabil platform med god Sinatra support
- Alle teammedlemmer kører samme version
- Forudsigeligt gem dependency management

**Ulemper:**

- Går glip af nyeste Ruby 4 features
- Fremtidig migration til Ruby 4 bliver nødvendig

**Læring:**

- Versionsstyring skal aftales tidligt i projektet
- Stabilitet > nyeste version ved framework dependencies
- Inkrementelle upgrades er bedre end store spring (som med Python migration)

------

## .gitignore Conflicts

### Context

Ved oprettelse af Ruby-projektet blev der automatisk genereret en `.gitignore` fil i `ruby-sinatra/` mappen. Dette skabte konflikt med den eksisterende `.gitignore` fra legacy projektet.

### Challenge

- To `.gitignore` filer (root og `ruby-sinatra/`) kunne ikke sameksistere
- Filer blev tracked forskelligt afhængig af hvilken `.gitignore` der havde forrang
- Merge conflicts opstod konstant mellem branches
- Forsøg på at oprette tredje `.gitignore` i root løste ikke problemet, da filer allerede var tracked

**Teknisk årsag:** Git tracker filer fra første commit. En ny `.gitignore` stopper ikke tracking af allerede committed filer.

### Choice

**Beslutning:** En enkelt `.gitignore` i repository root

**Proces:**

1. Lukkede alle aktive feature branches
2. Fjernede alle `.gitignore` filer
3. Oprettede ny samlet `.gitignore` i root
4. Untracked tidligere ignorerede filer med `git rm --cached`
5. Committed den nye struktur

**Fordele:**

- Konsistent ignore-logik på tværs af hele projektet
- Ingen merge conflicts fra competing `.gitignore` filer
- Simplere at vedligeholde

**Ulemper:**

- Krævede koordinering (alle branches skulle lukkes)
- Tabte tid på troubleshooting før vi fandt løsningen

**Læring:**

- `.gitignore` hierarki skal planlægges fra start
- Git tracking skal fjernes eksplicit med `git rm --cached`
- Mono repo kræver clear ignore strategy på tværs af sub-projekter

------

## Database File Tracking

### Context

`.db` filer (SQLite databases) blev tracked i Git fra projektets start. Forskellige teammedlemmer havde forskellige versioner af databasen i deres lokale branches.

### Challenge

- Database filer er binære - kan ikke merges som tekst
- Forskellige `.db` versioner på tværs af branches
- Impossible at løse merge conflicts i binære filer
- Tracking af database state skabte konstante conflicts

**Teknisk problem:** Binary files + Git merge = umuligt at reconcile

### Choice

**Beslutning:** Stop tracking af database filer, brug fresh database dumps i stedet

**Implementering:**

1. Tilføjede `.db` patterns til `.gitignore`:

```
   *.db
   *.db-shm
   *.db-wal
```

1. Fjernede alle `.db` filer fra Git history: `git rm --cached *.db`
2. Hentet fresh database dump til lokal udvikling
3. Dokumenterede database setup i README

**Fordele:**

- Ingen database merge conflicts
- Konsistent udviklings-database via dumps
- Mindre repository størrelse

**Ulemper:**

- Kræver setup step for nye udviklere
- Database state er ikke versioneret (men det skal den heller ikke være)

**Læring:**

- Binære filer (databases, builds, logs) hører ikke i Git
- Database schema versioneres via migrations, ikke via `.db` filer
- `.gitignore` skal konfigureres korrekt fra dag 1

------

## OpenAPI Specification Discrepancies

### Context

Vi har modtaget en reference OpenAPI spec fra underviser (Anders Latif) som vi skal efterleve. Samtidig har vi genereret en spec fra den eksisterende Python Flask applikation. Disse to specs er ikke identiske.

### Challenge

- Python-genereret spec har fejl (refererer til HTML responses i stedet for JSON)
- Underviser spec er autoritativ, men Python code har afviget
- Ruby/Sinatra har ingen automatisk spec generation tools (som OpenAPI decorators i Flask)
- Risiko for at porte Python fejl til Ruby implementation

**Eksempel på fejl:**

```python
# Python Flask - forkert response type
@app.route('/api/search')
def search():
    """
    Returns HTML page  # <- FORKERT: Burde være JSON
    """
    return render_template('search.html')
```

### Choice
**Beslutning:** Følg underviser spec som source of truth, brug Python kun som reference

**Implementering:**
- Undermapping mellem underviser spec og faktisk Ruby implementation
- Manuel spec maintenance (ingen auto-generation i Sinatra)
- Docstrings i Ruby bruges til manuel spec generation bagefter

**Proces:**
1. Implementer Ruby endpoint iht. underviser spec
2. Skriv docstring med endpoint beskrivelse
3. Test endpoint matcher spec (Postman/curl)
4. Opdater manuel spec hvis nødvendigt

**Fordele:**
- Correct API contracts fra start
- Ingen Python fejl portes til Ruby
- Lærer API design ved at følge spec nøje

**Ulemper:**
- Mere manuelt arbejde (ingen auto-generation)
- Sinatra mangler Flask-lignende spec decorators
- Kræver disciplin at holde spec synced med kode

**Retrospektiv:**
- Python spec kunne kun bruges til at *identificere* fejl, ikke som template
- Nima opdagede at korrekt workflow er: Skriv kode → Generer spec (ikke omvendt)
- Vi havde allerede skrevet Ruby kode baseret på Python - måtte tilbage og justere

**Læring:**
- OpenAPI spec skal være source of truth INDEN implementering
- Auto-generation tools er ikke altid tilgængelige (framework dependent)
- 1:1 porting mellem frameworks (Python→Ruby) kan kopiere fejl

------

## Programming Language Choice

### Context
Kursusbegrænsninger: Ikke Java, Python eller Node.js. Teamet skulle vælge et nyt sprog til rewrite af Flask applikationen.

### Challenge
- Ingen teammedlemmer havde Ruby erfaring
- Behov for microframework (ligesom Flask)
- Måtte balancere læringskurve vs. dokumentation tilgængelighed

**Overvejede alternativer:**
- **Go:** Performant, men meget forskellig fra OOP baggrund
- **PHP:** Outdated, mindre relevant for moderne DevOps
- **Ruby:** Læselig syntaks, stærk web framework økosystem

### Choice
**Beslutning:** Ruby + Sinatra framework

**Rationale:**
- Sinatra er lightweight microframework (direkte Flask analog)
- Ruby syntaks er læselig og begyndervenlig
- Omfattende dokumentation og community support
- Aktiv udvikling og vedligeholdelse

**Fordele (forudset):**
- Minder om Python i læsbarhed
- Sinatra er mindre kompleks end Rails
- God match til DevOps værktøjskæde

**Ulemper (forudset):**
- Læringskurve for helt nyt sprog
- Mindre udbredt i industrien end Node.js/Python
- Manglende auto-generation tools for specs

**Retrospektiv:**
- Ruby syntaks var faktisk hurtig at lære
- Sinatra simplicity var en fordel, men mangler conventions (se arkitektur valg)
- Havde vi vidst at spec auto-generation manglede, havde det måske påvirket valget

**Læring:**
- Framework økosystem er lige så vigtigt som sproget selv
- Microframework flexibility kræver mere manual opsætning

------

## Architecture Pattern Choice

### Context
Sinatra har ingen indbyggede conventions for projekt struktur (modsat Rails MVC convention-over-configuration). Teamet skulle selv definere arkitektur.

### Challenge
- Sinatra er meget barebones - ingen folder structure enforced
- Teamet kender MVC fra Spring Boot (Java)
- Behov for at balancere simplicity vs. organization

**Overvejede patterns:**
- **MVC (Model-View-Controller):** Kendt fra Spring Boot
- **Flat structure:** Alt i én fil (`app.rb`)
- **Service layer pattern:** Separate business logic

### Choice
**Beslutning:** MVC-inspireret struktur, men "så lavt niveau som muligt"

**Implementering:**

```markdown
ruby-sinatra/
├── app.rb              # Routes & controllers (direkte kode)
├── models/             # Database models
├── views/              # Templates (hvis nødvendigt)
└── public/             # Static assets
```

**Rationale:**

- MVC giver struktur teamet kender
- "Lavt niveau" = minimal abstraction, flækker kode direkte i `app.rb`
- Sinatra's flexibility tillader gradvis strukturering

**Fordele:**

- Kendt pattern fra Spring Boot
- Kan starte simpelt og refaktorere senere
- Tydelig separation mellem routes og models

**Ulemper:**

- Ingen Sinatra conventions at følge (må opfinde selv)
- Risiko for at `app.rb` bliver for stor
- "Lavt niveau" kan betyde mindre modular kode

**Retrospektiv:** (Opdateres løbende)

**Læring:**

- Microframeworks giver frihed, men kræver disciplin
- MVC kan tilpasses selv når framework ikke enforcer det
- Start simple, refaktorer når smertepunkter opstår

------

## Initial Deployment Strategy - week 3

### Context
- Vi skulle deploye første gang i uge 3 på Azure.
- Ingen CI endnu (kommer uge 4), Docker/CD kommer senere (uge 5–6).
- Skolens rettigheder krævede VM-oprettelse via scripts (ikke Azure Portal UI).
- Krav: statisk public IP (skal whitelist’es til simulation/underviser)

### Challenge
- Azure policies/regions var begrænsede → ikke alle regioner virkede.
- VM fik ikke automatisk “stabil” IP i vores første forsøg.
- Ruby-version mismatch på Ubuntu (3.0.2) vs projektets Ruby (3.2.3) → bundler mismatch.
- SQLite er en fil → skulle placeres korrekt + skrive-rettigheder (WAL/SHM).
- App skulle køre stabilt efter logout → krævede service management (systemd).
- Port-regler/NSG priority konflikter (22 vs 80).

**Overvejede alternativer:**
- SCP upload + manual restart (simpelt, men ikke reproducérbart)
- SSH + git pull + manual restart (simpelt, men drift “dør” ved logout uden service)
- Cron sync + auto restart (for meget “CD” nu)
- Build/CI/CD (for tidligt ift. kursusplan)

### Choice
**Beslutning:** Azure VM + manuel deploy via SSH + git clone/pull, med systemd til drift og Nginx som reverse proxy. Statisk public IP via Azure CLI.

**Implementering:**

```markdown
1) Opret VM via lærerens scripts (Azure CLI) + Static Public IP
2) SSH ind + apt update/full-upgrade + reboot
3) Installer Ruby 3.2.3 via rbenv (match dev) + bundler 4.0.6
4) Standard layout: /opt/whoknows/app (kode) + /opt/whoknows/data (db)
5) git clone repo → bundle install
6) Upload SQLite db med scp → styr sti via DB_PATH env-var
7) systemd service: starter app på 127.0.0.1:4567 og overlever reboot/logout
8) Nginx proxy: port 80 → 127.0.0.1:4567
9) Åbn port 80 i Azure NSG med unik priority (Azure CLI kommando)
10) Test i browser + curl mod /api/search
```

**Rationale:**
- Minimal løsning nu, men “klar til næste step”: systemd + Nginx passer direkte ind når vi senere Dockeriserer (bytter bare ExecStart/container).
- Reproducerbar drift uden CI/CD.
- Sikkerhed: app lytter kun på localhost; kun Nginx eksponeres på 80.

**Fordele:**
- Stabil runtime (systemd) + restart ved crash/reboot.
- Simple “deploy flow”: ssh → git pull → bundle install → systemctl restart.
- Statisk public IP gør whitelisting nem.
- Nginx gør senere TLS og routing nemmere.


**Ulemper:**
-Manuelt arbejde (ingen CI endnu).
- rbenv er ekstra setup/fejlkilde ift. PATH.
- SQLite som fil er ikke optimal til skalering.

**Retrospektiv:** (Opdateres løbende)
- Fejl i systemd pga RACK_ENV=production uden production: i database.yml → fixed ved at tilføje production config.
- Route /search gav 404 (mens /api/search virkede) → vurderet som kode-/wiring-issue, udskudt.
- 
**Læring:**
- Match runtime versions (Ruby/Bundler) mellem dev og prod tidligt.
- Env-vars + standard /opt layout gør deploy mere robust (vi kan flytte DB + repo uden at ændre koden).
- systemd + reverse proxy er “baseline” drift, også før CI/CD/Docker.
- Azure NSG rules kræver unikke priorities (undgå conflicts).

------

## OpenAPI Specification: Afvigelser fra whoknows-spec.json

### Context
Vi tog udgangspunkt i Anders' whoknows-spec.json som reference og tilpassede den til vores Ruby/Sinatra implementation. Undervejs identificerede vi steder hvor vores kode afveg fra spec, og tog bevidste beslutninger om hvad der skulle rettes og hvad der skulle beholdes.

### Challenge
Hvordan dokumenterer man et API der bevidst afviger fra referencen på enkelte punkter, uden at miste overblikket over hvad der er en fejl og hvad der er et aktivt valg?

### Choice

**Beslutning**: To bevidste afvigelser fra Anders' spec blev bibeholdt. Resten blev tilpasset til at følge hans spec så tæt som muligt, inklusiv brug af navngivne `$ref` schemas i components.

**Hvordan valget blev truffet:**
Vi gennemgik alle endpoints og schemas systematisk og sammenlignede dem med Anders' spec. For hver forskel vurderede vi om den skyldtes en fejl eller en bevidst implementationsbeslutning.

Afvigelse 1 — `GET /` dokumenterer query parameters `q` og `language`. Anders' spec dokumenterer dem ikke, fordi hans Python-implementation bruger en separat `/search` route. Vi mergede `/search` ind i `/` for at følge spec-strukturen, og dokumenterer derfor parametrene direkte på `/`.

Afvigelse 2 — `language` parameteren bruger `default: "en"` fremfor Anders' `anyOf string/null`. Vores kode bruger `params[:language] || 'en'`, hvilket betyder at parameteren aldrig er null i praksis.

**Fordele:**
- Spec afspejler hvad koden reelt gør
- Navngivne schemas i components følger DRY-princippet og gør spec lettere at vedligeholde
- Færre routes med samme funktionalitet

**Ulemper:**
- To punkter afviger fra Anders' spec, hvilket kan skabe forvirring ved direkte sammenligning
- `default: "en"` er mindre eksplicit om null-håndtering end `anyOf string/null`

**Læring:**
- OpenAPI er sprogagnostisk — spec beskriver hvad API'et gør, ikke hvordan det er implementeret
- Spec bør være en sandfærdig kontrakt for hvad API'et returnerer
- `$ref` i components er DRY-princippet anvendt på API dokumentation

------

## Implementering af GitHub Actions CI pipeline

### Context
Projektet migreres fra Flask til Sinatra.
Der var ingen automatisk validering af:
- Tests
- Code style
- Dependency consistency
Vi ønskede en deterministisk og reproducerbar build-proces.

### Challenge
- Monorepo struktur (Flask + Ruby i samme repo)
- Ruby-projekt ligger i subfolder (ruby-sinatra)
- Environment variables (SESSION_SECRET) manglede i CI
- Gemfile og Gemfile.lock skulle være synkroniseret

### Choice
**Beslutning:**
Vi implementerede en GitHub Actions CI pipeline med:
- ruby/setup-ruby
- Fast Ruby-version (3.2.3)
- Bundler install
- RuboCop lint step
- RSpec test step

**Rationale:**
- GitHub Actions er native i GitHub
- Minimal opsætning
- Understøtter caching og version pinning 

**Fordele (forudset):**
- Automatisk test ved push og pull request
- Deterministisk build (Ruby-version pinned)
- Fanger fejl før merge
- Sikrer Gemfile.lock konsistens (frozen mode)

**Ulemper (forudset):**
- Kræver korrekt environment setup
- Monorepo kræver eksplicit working-directory
- CI kan fejle på små lint-fejl (strengt setup)

**Retrospektiv:**


**Læring:**
- CI kører i et rent miljø – intet er implicit
- Environment variables skal eksplicit sættes
- Gemfile.lock er kritisk for stabile builds
- SHA pinning kan give kompatibilitetsudfordringer

------

## Integration af RuboCop som quality gate

### Context
Koden havde inkonsistent formatting og ingen style enforcement.
Projektet er i migreringsfase, hvilket øger risiko for teknisk gæld.

### Challenge
- 100+ initial offenses
- Windows line endings (CRLF)
- Strenge default regler
- Placeholder-metoder under migration

### Choice
**Beslutning:** Vi integrerede RuboCop med projekt-tilpasset .rubocop.yml.

**Rationale:**
- RuboCop er standard i Ruby-økosystemet
- Let integration i CI
- Understøtter safe og unsafe autocorrect
- Giver ensartet code style

**Fordele (forudset):**
- Konsistent kodebase
- Reducerer style-diskussioner i PR
- Automatisk enforcement via CI
- Etablerer clean baseline (0 offenses)

**Ulemper (forudset):**
- Kan virke rigidt 
- Kræver initial oprydning
- Regler skal tilpasses projektets fase

**Retrospektiv:**


**Læring:**
- Safe vs Unsafe autocorrect er vigtigt at forstå
- Lint bør tunes – ikke blindt accepteres
- Empty methods kan være legitime under migration

------

## 3rd party Integration af weather API

### Context
- Ny feature: vise vejrdata i applikationen via ekstern service.
- OpenAPI-spec krævede /api/weather (JSON) og /weather (HTML).
- Underviser simulerer load og kan ramme endpoint mange gange.

### Challenge
- Frontend eller backend implementering?

**Overvejede alternativer:**
- Frontend: Fetch direkte fra browser → mindre backend kode

### Choice
**Beslutning:** Backend implementering

**Implementering:**

```markdown
1) Valg af tredjepart: OpenWeather API (https://openweathermap.org/api)
2) Serviceklasse (WeatherService) isolerer integration fra routes
3) API key gemt i environment variable (OPENWEATHER_API_KEY)
4) GET /api/weather returnerer JSON (StandardResponse)
5) Tilføjede in-memory caching ved at bruge klasse-variabel for at reducere antal API calls som har rate limits på gratis subscription (10 min TTL)
```

**Rationale:**
Backend integration giver bedre kontrol over:
- Security (API key eksponeres ikke)
- Rate limiting (caching reducerer calls)
- Fejlhåndtering og fallback 
- Overholdelse af OpenAPI-kontrakt 

Valget understøtter DevOps-principper:
- Separation of concerns 
- Secret management via environment variables 
- Robusthed mod eksterne afhængigheder

**Fordele:**
- Rate limit kontrol med caching: et request sendes til API, 100 brugere får cached svar
- Ingen CORS problemer (hvis frontend fetcher direkte fra browser, skal API'en håndtere CORS headers)
- API nøgle eksponeres ikke i frontend
- Centraliseret fejlhåndtering i backend

**Ulemper:**
- Mere server load
- Mere kode: HTTP client, error handling, caching-logik, ENV variabler

**Retrospektiv:** (Opdateres løbende)
-OpenWeather API keys har aktiveringsforsinkelse (ikke instant)

**Læring:**
- Vigtigheden af at isolere ekstern integration i service layer
- Caching som strategi mod rate limiting og load

------

## API design: JSON vs HTML responses ved login

**Context**
`POST /api/login` skal ifølge spec'en returnere JSON. Legacy koden (Flask) håndterede derimod både login-logik og visning af fejlbeskeder server-side ved at returnere HTML direkte fra routen.

**Challenge**
Når en bruger logger ind med forkerte oplysninger via en HTML-formular, forventer browseren at blive sendt til en ny side eller få en opdateret side tilbage - ikke rå JSON. Det betød at fejlbeskeder ikke blev vist i viewet, men i stedet som JSON-tekst i browseren.

**Choice**
Håndtér redirect og fejlvisning via JavaScript i viewet frem for at lade serveren returnere HTML fra API-endpointet.

**Beslutning**
`POST /api/login` returnerer udelukkende JSON. JavaScript i `login.erb` intercepter form-submit, poster til API-endpointet og håndterer svaret - enten redirect til forsiden ved success eller visning af fejlbesked ved fejl.

**Hvordan valget blev truffet**
Spec'en definerer `POST /api/login` som et JSON-endpoint. At afvige fra det ville bryde spec'en og skabe en uklar adskillelse mellem API og frontend. Legacy koden brød faktisk spec'en på dette punkt.

**Fordele**
- Overholder spec'en
- Klar adskillelse mellem API og frontend
- API-endpointet kan bruges af andre klienter end browseren

**Ulemper**
- Kræver JavaScript i viewet
- Lidt mere kompleksitet i frontend

**Læring**
Når man designer et JSON API skal man tænke på hvem der konsumerer det. En browser forventer HTML, men et API-endpoint bør ikke tage hensyn til det - det er frontend-lagets ansvar at håndtere svaret.

------

## Database konfiguration: `set :database_file` placering

**Context**
I Sinatra modular style (`Sinatra::Base`) skal applikationskonfiguration defineres inden for applikationsklassen. `set` er en Sinatra-specifik metode der registrerer konfiguration på klassen.

**Challenge**
`set :database_file` var placeret i `config/environment.rb` uden for `WhoknowsApp` klassen. Konfigurationen blev derfor aldrig registreret korrekt af Sinatra, hvilket betød at ActiveRecord ikke fik besked om hvilken database den skulle forbinde til.

**Choice**
Flyt `set :database_file` ind i `WhoknowsApp` klassen i `app.rb`.

**Beslutning**
`set :database_file` placeres i `app.rb` inden i `WhoknowsApp` klassen. `config/environment.rb` håndterer kun gem-loading og generel opsætning.

**Hvordan valget blev truffet**
Fejlen blev opdaget ved at applikationen tilsyneladende virkede, men ActiveRecord's debug-log viste mistænkelig adfærd. Efter at have isoleret problemet til database-konfigurationen blev det klart at `set` ikke virker uden for en Sinatra-klasse.

**Fordele**
- Konfigurationen er garanteret registreret ved opstart
- Klar adskillelse - `environment.rb` loader gems, `app.rb` konfigurerer applikationen

**Ulemper**
- `app.rb` får lidt mere ansvar

**Læring**
Sinatra-specifikke metoder som `set` skal altid kaldes inden for applikationsklassen når man bruger modular style. Classic style (`require 'sinatra'`) ville have tilladt `set` uden for en klasse, men modular style kræver eksplicit klassekontekst.

------

## Test miljø: In-memory SQLite database

**Context**
RSpec-tests kørte lokalt uden problemer, fordi en `whoknows.db` SQLite fil eksisterede på udviklingsmaskinen. I CI (GitHub Actions) eksisterer denne fil ikke, da den er tilføjet til `.gitignore`.

**Challenge**
Uden en database-fil kastede ActiveRecord en exception ved første `User.find_by(...)` kald. Sinatra's globale `error`-blok fangede exceptionen og returnerede 500 i stedet for 422. Testen fejlede derfor konsekvent i CI:

```
expected: 422
     got: 500
```

Problemet var usynligt lokalt fordi databasen altid fandtes der.

**Choice**
Tilføj et dedikeret `test` miljø i `database.yml` der bruger SQLite `:memory:` og bootstrap schema i `spec_helper.rb` via `before(:suite)`.

**Beslutning**
- `config/database.yml` får en `test` sektion med `database: ":memory:"`
- `spec_helper.rb` sætter `ENV['RACK_ENV'] = 'test'` øverst så Sinatra/ActiveRecord vælger test-konfigurationen
- `before(:suite)` opretter `users` og `pages` tabeller i hukommelsen før testene kører

**Hvordan valget blev truffet**
In-memory SQLite er standard tilgangen til database-tests i Ruby-økosystemet. Det eliminerer filsystem-afhængigheder og giver hurtigere tests. Alternativet (at committe en `.db` fil eller oprette den i CI) ville have tilføjet unødvendig kompleksitet i CI-setup.

**Fordele**
- Tests er selvstændige og kræver ingen ekstern opsætning
- Kører identisk lokalt og i CI
- Hurtigere end fil-baseret SQLite (ingen disk I/O)
- Ingen risiko for at test-data forurener udviklingsdatabasen

**Ulemper**
- Schema i `spec_helper.rb` skal holdes synkroniseret med den faktiske tabelstruktur
- In-memory database nulstilles for hver testkørsel (men det er som regel ønskeligt)

**Læring**
CI afslører afhængigheder til lokalt miljø som er usynlige under udvikling. Database-filer må aldrig være en forudsætning for at køre tests - test-miljøet skal være fuldt selvforsynende og reproducerbart.

------

## Dockerfile og Docker Compose setup

### Context
Projektet MonkKnows er et Ruby 3.2.3 Sinatra mikroservice-projekt i et
monorepository. Der er behov for at containerisere applikationen til både lokal
udvikling og produktion.

### Challenge
- Udvikling og produktion har forskellige behov: dev kræver development gems og hot-reload, prod skal være minimal og sikker
- SQLite databasefilen skal være tilgængelig inde i containeren
- Miljøvariabler skal håndteres forskelligt lokalt og i CI/CD

**Overvejede patterns:**
- To separate Dockerfiles (Dockerfile.dev + Dockerfile.prod)
- Én Dockerfile med ARG til at styre gem-installation

### Choice
**Beslutning:** Én Dockerfile med multi-stage build og ARG BUNDLE_WITHOUT

**Implementering:**

```markdown
- Stage 1 (build): Installerer gems styret af ARG BUNDLE_WITHOUT
- Stage 2 (runtime): Kopierer kun nødvendige artefakter fra build stage
- docker-compose.dev.yml: Bruger target: build, volume-mount af kildekode og database
- docker-compose.prod.yml: Bygger hele Dockerfile, restart: unless-stopped
```

**Rationale:**
- Én Dockerfile reducerer vedligeholdelse
- ARG BUNDLE_WITHOUT="" i dev-compose inkluderer development gems uden at ændre Dockerfile
- Volume-mount i dev betyder kodeændringer er tilgængelige uden rebuild

**Fordele:**
- Én sandhed for build-processen
- Prod-image er minimalt – ingen development gems
- Lokal kørsel uden Docker stadig mulig via ENV.fetch fallback i database.yml

**Ulemper:**
- ARG-mekanismen er ikke helt intuitiv ved første møde
- SQLite volume-mount er en midlertidig løsning indtil PostgreSQL-migrering

**Retrospektiv:**
- DATABASE_PATH som miljøvariabel løste konflikten mellem lokal og Docker-sti til db

**Læring:**
- Docker Compose environment: vinder over env_file: ved konflikt
- Absolut sti i containeren (/whoknows.db) kombineret med ENV.fetch fallback
  giver fleksibilitet på tværs af miljøer

------

## Hot-reload med Guard frem for Rerun

### Context
Lokal udvikling i Docker kræver at serveren genstarter automatisk ved filændringer
så udviklere ikke manuelt skal genstarte containeren.

### Challenge
- Docker kører uden en rigtig TTY (terminal), hvilket skaber problemer for værktøjer
  der forventer interaktiv input
- Rerun forsøger at sætte terminalen op via stty, hvilket fejler i Docker og skaber
  konstant støj i loggen

**Overvejede patterns:**
- rerun gem med --no-notify og --quiet flags
- guard gem med guard-shell plugin

### Choice
**Beslutning:** Guard med guard-shell plugin

**Implementering:**
- Gemfile: guard og guard-shell tilføjet i group :development, :test
- Guardfile oprettet med watch på app.rb og lib/**/*.rb
- command i docker-compose.dev.yml: bundle exec guard --no-interactions --no-bundler-warning

**Rationale:**
- --no-interactions fortæller Guard at den ikke skal lytte på tastaturinput
- Guard er designet til baggrundskørsel uden interaktiv terminal

**Fordele:**
- Ingen støj i loggen
- Filændringer trigger automatisk servergenstart
- guard-shell tillader vilkårlige shell-kommandoer som reaktion på filændringer

**Ulemper:**
- Kræver både guard og guard-shell gems
- Guardfile er et ekstra konfigurationslag at vedligeholde

**Retrospektiv:**
- Rerun virkede funktionelt men stty-fejlene gjorde det svært at læse fejlbeskeder
  i konsollen under udvikling

**Læring:**
- Værktøjer designet til interaktiv brug fungerer dårligt i Docker uden TTY
- --no-interactions er det afgørende flag der løser TTY-problemet

------

## Continuous Delivery pipeline til GitHub Container Registry

### Context
Projektet har en eksisterende CI pipeline der kører tests og linting. Der er behov
for at udvide med Continuous Delivery så et produktionsklar Docker image automatisk
bygges og pushes til et container registry ved merge til main.

### Challenge
- CI skal køre på både main og development, men CD må kun køre på main
- .env filen er ikke i git, men docker-compose.prod.yml refererer til den
- Credentials skal håndteres sikkert i CI/CD miljøet

**Overvejede patterns:**
- Extend eksisterende ci.yaml med et ekstra job
- Separat cd.yaml workflow fil

### Choice
**Beslutning:** Separat cd.yaml med docker buildx bake

**Implementering:**
- cd.yaml trigges kun på push til main
- docker buildx bake læser docker-compose.prod.yml og bygger image
- Credentials håndteres som GitHub Secrets og loades som environment variabler
- env_file: fjernet fra docker-compose.prod.yml – erstattet af ${VARIABEL} syntax

**Rationale:**
- Separat fil giver klar adskillelse af ansvar: ci.yaml tester, cd.yaml leverer
- docker buildx bake genbruger docker-compose.prod.yml som single source of truth
- GitHub Secrets er den sikre måde at håndtere credentials i CI/CD

**Fordele:**
- CI og CD har tydeligt adskilte ansvarsområder
- Image pushes kun til GHCR når tests er grønne og kode er på main
- Ingen credentials i git

**Ulemper:**
- Secrets skal oprettes manuelt i GitHub og på serveren
- cd.yaml kører ikke tests selv – stoler på at ci.yaml har gjort sit arbejde

**Retrospektiv:**
- env_file: i docker-compose.prod.yml var en fælde i CI da .env ikke er i git
- ${VARIABEL} syntax i compose kombineret med GitHub Secrets løste problemet elegant

**Læring:**
- env_file: er praktisk lokalt men uegnet i CI/CD
- docker buildx bake er mere elegant end build-push-action da det genbruger
  eksisterende compose-konfiguration

------

## CI pipeline inkonsistens ved PR til main (ift. RuboCop)

### Context
Projektet bruger GitHub Actions til CI med RuboCop og RSpec.
Under merge fra development → main opstår der en fejl i CI, som ikke kan reproduceres lokalt.
Den rapporterede fejl (Style/RescueModifier) findes ikke i den aktuelle kodebase.

### Challenge
- CI rapporterer fejl i kode, som ikke eksisterer i repository
- Lokalt miljø og CI miljø er ude af sync
- Flere forsøg på fix (lint, branches, ny PR) uden effekt

**Overvejede patterns:**
- 

### Choice
**Beslutning:** Acceptere problemet som en CI inkonsistens (forældet cache / forkert reference) og fortsætte med workaround (ny PR / manuel re-run)

**Implementering:**

```markdown
- Opret ny PR fra development → main 
- Trigger CI manuelt (Re-run jobs) 
- Verificer kode i GitHub UI vs lokal
```

**Rationale:**
- CI pipelines kan tilsyneladende arbejde på cached eller forældede commits, måske pga. vores branch flows og protected branches.

**Fordele:**
- Hurtig løsning ift. at bibeholde vores development flow
- Minimal tid brugt på debugging af eventuel ekstern systemfejl

**Ulemper:**
- Underliggende problem ikke løst
- Kan skabe usikkerhed om CI pålidelighed

**Retrospektiv:** 
- Problemet tyder på mismatch mellem CI context og repository state
- Skal løses for at sikre tillid til CI som “source of truth” i fremtiden, hvis problem opstår ved næste merge mod main

**Læring:**
- CI er “source of truth” – men kan stadig have inkonsistenser
- Verificer altid hvilken kode CI faktisk kører
- Branch protection + PR flow kan introducere kompleksitet i pipelines

------

## HTML ID-kompatibilitet med legacy frontend

### Context
Underviser kører en simulation der automatisk klikker rundt på projektets frontend. Simulationen er skrevet mod legacy Flask-projektet og bruger specifikke HTML `id`-attributter til at finde og interagere med elementer på siden (søgefelt, søgeknap, resultatcontainer).

### Challenge
- Ruby/Sinatra rewritet havde ikke de samme `id`-attributter som legacy Flask-projektet på søgesiden
- Legacy Flask brugte `id="search-input"`, `id="search-button"` og `id="results"` i `search.html`
- Vores `index.erb` (som håndterer samme route `/`) manglede alle tre IDs
- Simulationen ville fejle fordi den ikke kunne finde de forventede elementer

**Overvejede patterns:**
- Lade simulationen fejle og afvente feedback fra underviser
- Tilpasse vores IDs til at matche legacy-koden

### Choice
**Beslutning:** Tilføj de tre manglende `id`-attributter til `index.erb` så de matcher legacy-koden præcist

**Implementering:**

```markdown
- id="search-input"  tilføjet til <input type="text" name="q">
- id="search-button" tilføjet til <button type="submit">
- id="results"       tilføjet til <div class="search-results"> (class bevaret)
```

**Rationale:**
- Simulationen er en ekstern afhængighed vi ikke kontrollerer – vi tilpasser os den
- Ændringen er rent additiv (IDs tilføjes, intet fjernes eller omdøbes)
- CSS påvirkes ikke: eksisterende class-selectors (`.search-results`, `input[name="q"]`) fungerer stadig

**Fordele:**
- Simulationen kan interagere korrekt med vores frontend
- Ingen visuel eller funktionel ændring for rigtige brugere
- CSS-styling forbliver uændret

**Ulemper:**
- Vi er bundet til legacy-projektets navngivningskonventioner for disse tre elementer
- Hvis legacy-projektet ændrer sine IDs skal vi følge med

**Retrospektiv:** (Opdateres løbende)
-

**Læring:**
- Ekstern simulationsafhængighed kræver at frontend-kontrakter (HTML IDs, classes) behandles som en del af API-kontrakten
- Additiv tilgang (tilføj ID, bevar class) er den mindst risikable måde at opnå kompatibilitet uden at bryde eksisterende styling

------

## JSON Body Parsing i Sinatra

### Context
Anders' simulator tester vores `/api/login` og `/api/register` endpoints ved at sende requests med både JSON body og form-encoded format. Sinatra parser ikke JSON body automatisk ind i `params`, modsat Flask som håndterer dette med `request.get_json()`.

### Challenge
- Simulatoren returnerede 422 på alle login-forsøg fra dag ét
- Fejlen var ikke en manglende bruger, men at `params[:username]` altid var `nil` ved JSON requests
- Problemet ramte alle POST endpoints der læser fra `params`

**Overvejede patterns:**
- Parse JSON body individuelt i hver route
- Centraliseret parsing i `before` block der merger ind i `params`
- `Rack::JSONBodyParser` middleware

### Choice
**Beslutning:**
Centraliseret JSON parsing i den eksisterende `before` block, begrænset til POST requests med eksplicit fejlhåndtering.

**Implementering:**
```ruby
before do
  @current_user = nil
  @current_user = User.find_by(id: session[:user_id]) if session[:user_id]

  if request.post? && request.content_type&.include?('application/json')
    request.body.rewind
    begin
      json_body = JSON.parse(request.body.read, symbolize_names: false)
      # ||= sikrer at eksisterende params ikke overskrives af JSON body
      if json_body.is_a?(Hash)
        json_body.each { |k, v| params[k] ||= v }
      else
        content_type :json
        halt 400, { detail: [{ loc: ['body'], msg: 'Expected JSON object', type: 'type_error' }] }.to_json
      end
    rescue JSON::ParserError
      # Returnér 400 ved malformed JSON frem for at fejle stille
      content_type :json
      halt 400, { detail: [{ loc: ['body'], msg: 'Invalid JSON', type: 'parse_error' }] }.to_json
    end
  end
end
```

**Rationale:**
- Løser problemet ét sted frem for at duplikere logikken i hver route
- Ændrer ikke OpenAPI spec eller eksisterende route-logik
- `||=` sikrer at eksisterende params ikke overskrives
- Valgt frem for `Rack::JSONBodyParser` middleware på grund af behovet for eksplicit fejlhåndtering

**Fordele:**
- Alle nuværende og fremtidige routes får automatisk JSON support
- Routes forbliver uændrede og læsbare
- Understøtter både form-encoded og JSON uden at vælge én standard
- Malformed JSON returnerer 400 med en beskrivende fejlbesked og korrekt `Content-Type` header
- JSON arrays og primitiver afvises med 400 frem for at fejle med `NoMethodError`
- Begrænset til POST requests, så GET routes ikke påvirkes unødigt
- Koden er synlig og forståelig direkte i app.rb

**Ulemper:**
- Workaround frem for en Rack-native løsning - `Rack::JSONBodyParser` middleware ville være mere idiomatisk
- Ligger i applikationslaget frem for middleware-laget hvor request transformation hører hjemme

**Alternativ overvejet - `Rack::JSONBodyParser`:**
- Idiomatisk Rack løsning der vedligeholdes af Rack frem for os
- Fravalgt fordi malformed JSON håndteres stille uden mulighed for at returnere en beskrivende fejlbesked
- Fravalgt fordi middleware er mindre synlig for nye udviklere på projektet

**Retrospektiv:** (Opdateres løbende)
- Fejlen stod på fra første deployment den 26. februar uden at blive opdaget, fordi vi ikke havde monitoring på response codes
- Coderabbit identificerede to edge cases under PR review: manglende type validering og manglende `Content-Type` header på fejlresponses

**Læring:**
- Flask og Sinatra håndterer content negotiation forskelligt - Sinatra er mere eksplicit
- Monitoring af response codes er nødvendigt for at opdage denne type fejl tidligt
- 422 fra simulatoren er et bedre signal end "manglende bruger" - fejlkoden pegede på valideringsfejl, ikke autentificeringsfejl
- Rack middleware og applikationslaget løser samme problem på forskelligt abstraktionsniveau - valget afhænger af hvor meget kontrol man har brug for
- Automatisk PR review med Coderabbit fangede edge cases som ikke var åbenlyse under implementation

------

## Continuous Deployment Pipeline med GitHub Actions

### Context
Projektet whoknows_variations er en Ruby 3.2.3 Sinatra mikroservice der kører i Docker på en Azure VM.
Vi havde allerede en CI pipeline (ci.yaml) der kørte tests, men ingen automatisk deployment.
Målet var at implementere en fully automatic CD pipeline så ethvert push til main automatisk
resulterer i et nyt Docker image der deployes til produktionsserveren uden manuel intervention.

### Challenge
Den eksisterende cd.yaml byggede og pushede et Docker image til GHCR med `docker buildx bake`,
men stoppede der. Serveren blev aldrig opdateret automatisk. Derudover var secrets bagt ind i
Docker imaget og synlige i klartekst via `docker inspect`.

**Overvejede patterns:**
- `docker buildx bake` med docker-compose.prod.yml som build-definition
- `docker buildx build` med eksplicit Dockerfile og build-kontekst
- Tredjeparts GitHub Marketplace actions (appleboy/ssh-action) til SSH og SCP
- Native `ssh` og `scp` kommandoer direkte i workflow

### Choice

**Beslutning:**
Vi valgte `docker buildx build` med eksplicit Dockerfile frem for `docker buildx bake`, og native
`ssh`/`scp` frem for tredjeparts actions. Secrets håndteres via en `.env`-fil der genereres
dynamisk af GitHub Actions fra GitHub Secrets og overføres til serveren ved hver deployment.

**Implementering:**
```yaml
jobs:
  build-push:
    steps:
      - name: Build and Push Docker image
        run: |
          docker buildx build \
            --platform linux/amd64 \
            --push \
            -t ghcr.io/${{ env.DOCKER_GITHUB_USERNAME }}/monkknows:latest \
            -f ruby-sinatra/Dockerfile \
            ruby-sinatra/

  deploy:
    needs: build-push
    steps:
      - name: Add SSH key to runner
        run: |
          mkdir -p ~/.ssh/
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/ssh_key
          chmod 600 ~/.ssh/ssh_key
          printf '%s\n' "${{ secrets.SSH_KNOWN_HOSTS }}" > ~/.ssh/known_hosts
          chmod 644 ~/.ssh/known_hosts

      - name: Create .env file
        run: |
          cat > .env <<'EOF'
          SESSION_SECRET=${{ secrets.SESSION_SECRET }}
          OPENWEATHER_API_KEY=${{ secrets.OPENWEATHER_API_KEY }}
          EOF

      - name: Copy runtime files to server
        run: |
          scp -i ~/.ssh/ssh_key \
            .env ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:/opt/whoknows/app/.env
          scp -i ~/.ssh/ssh_key \
            docker-compose.prod.yml \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:/opt/whoknows/app/docker-compose.prod.yml
          scp -i ~/.ssh/ssh_key \
            nginx.conf \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }}:/opt/whoknows/app/nginx.conf

      - name: Deploy on server
        run: |
          ssh -i ~/.ssh/ssh_key \
            ${{ secrets.SSH_USER }}@${{ secrets.SSH_HOST }} << "EOF"
            set -euo pipefail
            cd /opt/whoknows/app
            docker compose -f docker-compose.prod.yml pull
            docker compose -f docker-compose.prod.yml up -d --remove-orphans
          EOF

  smoke-test-cd:
    needs: deploy
```

**Rationale:**
- `docker buildx bake` kræver en `build:`-blok i docker-compose.prod.yml, hvilket ville betyde
  at secrets risikerer at blive bagt ind i imaget under byggeprocessen
- Native `ssh`/`scp` er sikrere end tredjeparts actions da credentials ikke overdrages til
  en ekstern action der potentielt kan være kompromitteret
- `.env`-filen genereres dynamisk fra GitHub Secrets og eksisterer aldrig i repository

**Fordele:**
- Fuldt automatisk deployment ved push til main – ingen manuel SSH intervention
- Secrets injiceres runtime via `.env` og bages aldrig ind i Docker imaget
- Serveren verificeres mod kendte fingerprints via SSH_KNOWN_HOSTS – beskytter mod MITM-angreb
- `set -euo pipefail` sikrer at pipelinen fejler hurtigt ved fejl frem for at deploye et forældet image
- Smoke test verificerer at produktionsserveren svarer med HTTP 200 efter deployment
- Native SSH/SCP uden tredjeparts actions følger lærers sikkerhedsanbefaling

**Ulemper:**
- `SSH_KNOWN_HOSTS` skal opdateres manuelt hvis serveren skifter IP eller geninstalleres
- `.env`-filen overskrives ved hver deployment – eventuelle manuelle ændringer på serveren mistes
- Ingen automatisk rollback hvis smoke test fejler efter deployment

**Retrospektiv:** (Opdateres løbende)
- Secrets var initialt bagt ind i Docker imaget og synlige via `docker inspect` – opdaget ved
  gennemgang af sikkerhed og rettet ved at fjerne `build:`-blokken fra docker-compose.prod.yml

**Læring:**
- `docker-compose.prod.yml` må ikke indeholde en `build:`-blok når den bruges til deployment –
  den skal udelukkende referere til et færdigt image fra GHCR
- GitHub Actions substituerer `${{ secrets.X }}` før shell'en eksekverer scriptet – derfor skal
  heredoc bruges med single-quoted `<<'EOF'` for at undgå utilsigtet shell-ekspansion af secrets
- `set -euo pipefail` er essentielt i remote SSH-blokke for at undgå silent failures hvor
  pipelinen rapporterer success med et forældet image

------

## Kritiske sikkerhedsfixes: MD5 → bcrypt migration

### Context
En sikkerhedsaudit afslørede fire kritiske sårbarheder i authentication-koden: MD5 password hashing uden salt, en password verification bypass, credential leak til logs, og forudsigelig session secret i production.

### Challenge
- MD5 er kryptografisk brudt og bruges uden salt
- `verify_password?` accepterede rå MD5-hashen som gyldigt password input
- `warn()` og `puts params.inspect` lækkede credentials til stdout/logs
- Session secret faldt tilbage til `'x' * 64` hvis env var manglede
- Eksisterende brugere i databasen har MD5-hashede passwords der skal migreres uden nedetid

**Overvejede patterns:**
- Big bang migration: tving alle brugere til password reset
- Gradvis migration: re-hash ved næste login

### Choice
**Beslutning:** Gradvis migration fra MD5 til bcrypt med dual-hash verificering

**Implementering:**
```markdown
1) Tilføjet bcrypt gem
2) Ny kolonne password_digest tilføjet via migration script
3) User model omskrevet: verify_password? tjekker bcrypt først, falder tilbage til MD5, re-hasher til bcrypt ved succesfuldt MD5 login
4) Nye brugere oprettes kun med bcrypt (password_digest)
5) Password bypass (|| password == input) fjernet
6) Debug logging fjernet fra login route
7) Session secret raiser error i production hvis ikke sat
8) Migration script kørt manuelt på produktionsserver inden deploy
```

**Rationale:**
- Gradvis migration undgår tvunget password reset for alle brugere
- Dual-hash approach sikrer bagudkompatibilitet under overgangsperiode
- Migration ved login betyder at aktive brugere migreres automatisk
- `User.where.not(password: nil).count` kan monitoreres — når 0, fjernes MD5 kolonnen

**Fordele:**
- Ingen nedetid eller tvunget password reset
- Aktive brugere migreres automatisk ved login
- Inaktive brugere med MD5 kan tvinges til reset senere
- Alle fire sikkerhedshuller lukket i én samlet PR

**Ulemper:**
- To kolonner (password + password_digest) skal sameksistere midlertidigt
- Kode-kompleksitet i verify_password? indtil MD5 kolonnen fjernes
- Migration script skal køres manuelt på serveren inden deploy

**Retrospektiv:**
- CI fejlede første gang pga. RuboCop gem ordering — bcrypt skulle sorteres alfabetisk i Gemfile
- Migration script blev kørt på serveren via SSH inden PR merge for at undgå nedetid

**Læring:**
- Database migrations skal koordineres med deploys — koden og databasen skal matche
- Gradvis migration er sikrere end big bang for authentication-kritisk kode
- Sikkerhedsaudit bør være en fast del af code review processen

------

## Transition til trunk-based development

### Context
Projektet brugte Git Flow med development og main branches. Med stigende CI/CD modenhed var den ekstra branch-kompleksitet unødvendig og bremsede delivery.

### Challenge
- development og main var ude af sync (begge havde unikke commits)
- Duplikerede branch protection rulesets (4 rulesets, 2 per branch)
- Stale feature branches levede efter merge
- Inkonsistente commit messages (mix af dansk/engelsk, med/uden prefix)
- Alle merge-strategier var tilladt (merge commit, rebase, squash)

**Overvejede patterns:**
- Behold Git Flow med strengere regler
- Trunk-based development med feature branches direkte fra main

### Choice
**Beslutning:** Trunk-based development med main som eneste langlivede branch

**Implementering:**
```markdown
1) Synkroniseret main og development via PR
2) Default branch skiftet til main
3) Duplikerede rulesets slettet (4 → 2)
4) Branch protection opdateret: dismiss stale reviews + required thread resolution
5) Kun squash merge tilladt
6) deleteBranchOnMerge slået til
7) Stale branches arkiveret som tags (archive/*) og slettet
8) Commit konvention aftalt: Conventional Commits (feat/fix/chore/docs/ci), engelsk, lowercase
9) development arkiveret efter final sync til main
```

**Rationale:**
- Trunk-based passer bedre til teamets størrelse (3 personer) og CI/CD modenhed
- Squash merge giver ren main-historik hvor hver commit = én feature/fix
- Conventional Commits gør historikken søgbar og muliggør automatisk changelog
- Med squash merge er det kun PR-titlen der tæller i main

**Fordele:**
- Simplere branching model — færre merge conflicts
- Hurtigere feedback loop — PRs går direkte mod main
- Renere git historik med squash merge
- Automatisk branch cleanup efter merge

**Ulemper:**
- Kræver at PRs er små og selvstændige (kan ikke samle store features over tid)
- Alle på teamet skal være enige om konventionen
- Mister detaljeret commit-historik inden for en PR (squash)

**Retrospektiv:**
- development branch var beskyttet og krævede PR — synkronisering kunne ikke pushes direkte
- Arkivering af branches som tags gav en sikkerhedsnet der gjorde teamet mere komfortable med sletning

**Læring:**
- Branch-strategi bør matche teamets modenhed og CI/CD setup
- Trunk-based kræver tillid til CI — alle tests skal være grønne før merge
- Squash merge og Conventional Commits komplementerer hinanden

------

## CI/CD/CF pipeline omstrukturering

### Context
Projektet havde 5 separate GitHub Actions workflow-filer (ci.yaml, cd.yaml, brakeman.yml, bundler_audit.yml, owasp_zap.yml). Kursusmaterialet definerer fire DevOps-stadier: CI, Continuous Delivery, Continuous Deployment og Continuous Feedback.

### Challenge
- 5 workflow-filer var svære at overskue og mapppede ikke til DevOps-stadierne
- Alle security scanning workflows triggede på både main og development
- CD brugte usikker shell-baseret `docker login` der kunne lække credentials i logs
- Docker images blev kun tagget med `:latest` — ingen sporbarhed til specifikke commits
- Ingen container image scanning (Trivy) inden deploy
- Ingen Dependabot konfiguration

**Overvejede patterns:**
- Én stor workflow-fil med alle jobs
- Workflows grupperet efter DevOps-stadie (CI/CD/CF)

### Choice
**Beslutning:** 3 workflow-filer mappet til CI/CD/CF med optimeret job-rækkefølge

**Implementering:**
```markdown
ci.yml — Continuous Integration:
  1) Bundler Audit + Brakeman + Hadolint (parallel, ~10s hver)
  2) RuboCop + RSpec (afhænger af quality gates)
  3) Smoke test (afhænger af build-test)

cd.yml — Continuous Delivery & Deployment:
  1) Build Docker image lokalt (uden push)
  2) Trivy scan af lokalt image (CRITICAL/HIGH fejler pipeline)
  3) Push til GHCR kun hvis scan bestod
  4) Deploy til produktion via SSH
  5) Production smoke test

cf.yml — Continuous Feedback:
  1) OWASP ZAP dynamisk sikkerhedsscanning mod kørende app

Desuden:
- docker/login-action erstatter shell docker login
- docker/metadata-action + docker/build-push-action giver SHA og semver tagging
- dependabot.yml konfigureret for bundler, docker og github-actions
```

**Rationale:**
- CI (statisk analyse af kode/dependencies) → CD (artifact build/scan/deploy) → CF (dynamisk test af kørende app) følger kursets DevOps-model
- Hurtigste jobs kører først og parallelt — fejler Bundler Audit på 9 sekunder, sparer vi de resterende 2+ minutter
- Trivy scanner det buildede image *inden* push til GHCR — sårbare images når aldrig registryet
- Samme image pushes som scannes (ingen rebuild) efter CodeRabbit review feedback

**Fordele:**
- Klar mapping mellem workflow-filer og DevOps-stadier
- Parallelle quality gates reducerer CI-tid
- Sårbare images blokeres inden de når GHCR
- Docker images er sporbare via git SHA tag
- Dependabot holder dependencies opdateret automatisk

**Ulemper:**
- Konsolidering gør individuelle workflow-filer længere
- Trivy scan-before-push kræver lokal build + push som separate steps
- CodeRabbit konfiguration (`.github/cr`) ligger stadig som separat fil uden `.yml` extension

**Retrospektiv:**
- Første iteration pushede image til GHCR før Trivy scan — CodeRabbit fangede at sårbare images kunne nå registryet
- Anden iteration brugte to separate docker/build-push-action invocations — CodeRabbit fangede at det andet build producerede et nyt artifact
- Tredje iteration bruger `docker push` direkte på det scannede image

**Læring:**
- Pipeline-design er iterativt — code review (menneskelig og automatisk) fanger arkitekturfejl
- "Scan before push" kræver bevidst design: build med `load: true`, scan, derefter `docker push`
- Job-rækkefølge og parallelitet har reel indflydelse på developer experience og feedback-tid
- Workflow-filer bør organiseres efter formål (CI/CD/CF), ikke efter tool (brakeman/trivy/zap)

------

## Sikr systemet med snyk og Docker Scout

### Context
Snyk og Docker Scout blev evalueret som supplement til eksisterende sikkerhedsværktøjer i CI/CD-pipeline.

### Challenge
- Vurdere om Snyk og Docker Scout tilbyder merværdi oven på eksisterende sikkerhedsværktøjer.

### Choice
**Beslutning:**
Snyk fravalgt — bundler-audit og brakeman dækker samme behov uden ekstern afhængighed.
Docker Scout valgt som supplement til Trivy i CD-pipeline.

- Bundler-audit scanner dependencies mod Ruby Advisory Database
- Brakeman udfører statisk kodeanalyse for sikkerhedssårbarheder
- Snyk kræver ekstern konto og har begrænsninger på gratis tier
- Snyk ville primært tilføje dashboard og alerts — ikke øget sikkerhedsdækning for et Ruby Sinatra-projekt
- Trivy blokerer allerede pipeline ved CRITICAL/HIGH fund
- Docker Scout tilføjes som informativ scanning med anden database end Trivy — ingen ekstra secrets da GHCR-login 
genbruges

**Rationale:**
- To specialiserede Ruby-værktøjer foretrækkes frem for Snyk
  Docker Scout og Trivy supplerer hinanden da de slår op i forskellige CVE-databaser

### Læring
- Docker Scout kunne ikke integreres med GitHub Actions uden brugerkonto hos Docker Hub, derfor
blev det fravalgt i CI, da Trivy dækker samme behov uden ekstern afhængighed

------

## Observatory resultater 

### Context
Projektet kører som en Ruby Sinatra-mikroservice bag Nginx på monkknows.dk. Mozilla Observatory blev kørt som del af 
sikkerhedsreviewet: observatory.mozilla.org

### Challenge
Observatory-scanningen afslørede tre kritiske sikkerhedsproblemer der tilsammen kostede −85 point:
- Ingen CSP-header (XSS-angreb muligt)
- Session-cookie uden Secure-flag (session hijacking muligt)
- Ingen HSTS (bruger kan ramme HTTP første besøg)

### Choice
**Beslutning:** Adressér alle tre kritiske fund via nginx.conf og sikr at cookies sættes korrekt i Sinatra-appen.

**Implementering:**

```markdown
Rettelser foretaget:
1. CSP-header tilføjet i nginx.conf
2. HSTS-header tilføjet i nginx.conf
3. Referrer-Policy tilføjet i nginx.conf
4. Secure-flag på session-cookie i Sinatra-app

Eksisterende og velfungerende:
- X-Content-Type-Options: nosniff
- X-Frame-Options: SAMEORIGIN
- HTTPS-redirect
- CORS ikke eksponeret
```

**Rationale:**
- HSTS og CSP er de to mest impactfulde headers for en offentlig webapp
- Secure-flag på cookies er lav indsats, høj sikkerhedsgevinst
- Rettelserne foretages i Nginx så de gælder uafhængigt af applikationslaget

**Fordele:**
- Eliminerer de tre kritiske fund og forbedrer Observatory-score markant
- Nginx-niveau rettelser kræver ingen kodeændringer i Sinatra
- HSTS sikrer at fremtidige besøg altid bruger HTTPS

**Ulemper:**
- CSP kan bryde ekstern CSS/JS hvis den sættes for restriktivt
- HSTS er svær at rulle tilbage når den først er sat (browsere husker den)

**Retrospektiv:** (Opdateres løbende)
- Sikkerheds-headers er en hurtig gevinst men kræver test — især CSP kan have utilsigtede konsekvenser for applikationens 
funktionalitet

------

## Sikr serveren med Lynis

### Context
Produktionsserveren (whoknows-vm, Ubuntu 22.04 LTS på Azure) blev auditeret med Lynis som del af sikkerhedsreviewet.
Hardening Index: 64/100.

### Challenge
- Lynis identificerede én kritisk warning og flere SSH-relaterede sårbarheder med standardindstillinger der er for løse 
til en produktionsserver.

### Choice
**Beslutning:** Adressér den kritiske warning og SSH-hardening. Acceptér øvrige suggestions som kendte begrænsninger 
på en cloud-VM.

**Implementering:**

```markdown
Kritisk warning:
- KRNL-5830: Serveren genstartet efter ventende kernel-opdatering

SSH-hardening (/etc/ssh/sshd_config):
- LogLevel: INFO → VERBOSE
- MaxAuthTries: 6 → 3
- MaxSessions: 10 → 2
- AllowAgentForwarding: yes → no
- AllowTcpForwarding: yes → no
- X11Forwarding: yes → no
- Compression: yes → no
- ClientAliveCountMax: 3 → 2

Fail2ban:
- DEB-0880: jail.conf kopieret til jail.local

Accepteret risiko:
- BOOT-5122: GRUB password — ikke relevant på cloud-VM (ingen fysisk adgang)
- FILE-6310: Separate partitioner — kræver VM-opsætning
- USB-1000: USB-drivere — ikke relevant på cloud-VM
- HTTP-6710: Lynis detekterer ikke vores HTTPS korrekt
```

**Rationale:**
- SSH er den primære adgangsvej til serveren — hardening her har størst sikkerhedsgevinst
- Accepteret risiko dokumenteres eksplicit frem for at ignoreres

**Læring:**
- Lynis skelner ikke mellem cloud-VM og fysisk server — mange suggestions er irrelevante i cloud-kontekst og kræver 
aktiv stillingtagen frem for blind implementering

------

## Implementering af tests

### Context
Under migrering fra Flask til Sinatra blev der ikke implementeret tests, da fokus var på at få en funktionel MVP op at 
køre. Nu hvor projektet er stabilt og CI/CD pipelines er på plads, er det tid til at implementere tests for at sikre 
kvalitet og muliggøre fremtidige ændringer uden frygt for regressionsfejl.

### Challenge
- Strukturering af eksisterende tests
- Tilføj en Playwright end-to-end test for søgefunktionen
- Dokumentér testvalg

**Overvejede patterns:**
**Overvejede patterns:**

| Type | Status | Begrundelse |
|------|--------|-------------|
| Unit tests | ✅ Implemented | Tester isolerede model-metoder (User.hash_password) uden DB eller HTTP |
| Integration | ✅ Implemented | Rack::Test spinner appen op in-process og tester HTTP-endpoints med DB |
| E2E | ✅ Implemented | Playwright tester brugerflows mod live app i Docker |
| Performance | ❌ Not relevant | Mikroservice med lavt load — ingen SLA-krav i kurset |
| Contract | ✅ Implemented | Appen skal leve op til en OpenAPI-spec defineret af læreren. Contract tests verificerer at JSON-responses matcher de definerede schemas (AuthResponse, SearchResponse, StandardResponse). Implementeret i RSpec uden ekstern afhængighed da spec er lille og stabil |

### Choice
**Beslutning:**
- ´bundle exec rspec´ kører unit- og integrationstests i ci.yml (spec/unit & spec/integration)
- E2E-tests kører som et parallelt job i ci.yml — starter samtidig med quality gates og blokerer ikke hurtig feedback på unit/integration tests

**Implementering:**

```bash
bundle exec rspec                       # unit + integration
cd spec/e2e && npx playwright test      # e2e (kræver app kørende lokalt)
```
**Rationale:**
- Tests blev introduceret efter en stabil MVP, med fokus på de mest kritiske dele: autentificeringslogik (unit) og 
HTTP-endpoint-opførsel (integration)
- Testpyramiden er overholdt — mange hurtige unit tests i bunden, færre langsommere E2E-tests i toppen
- Rack::Test blev valgt til integrationstests fordi den kører in-process uden en rigtig server, hvilket gør tests 
hurtige og pålidelige i CI uden portkonflikter eller opstartstid (fordi mange jobs i CI kører parallelt)

**Fordele:**
- Unit tests kører uden database eller HTTP-stack — hurtig feedback på under 2 sekunder lokalt
- Integrationstests dækker reel route-opførsel inklusiv session-håndtering og JSON-responses
- E2E-tests fanger regressioner der kun opstår i et fuldt kørende Docker-miljø
- E2E kører som parallelt job i CI — blokerer ikke hurtig unit/integration-feedback, men alt er samlet i én fil

**Ulemper:**
- Lokal test af E2E kræver at appen kører, hvorefter Playwright skal køres i en separat terminal > friktion

**Retrospektiv:** (Opdateres løbende)
- Tests blev skrevet efter implementering frem for sideløbende — TDD ville have gjort det nemmere at designe testbare
metoder fra starten

**Læring:**
- ActiveRecord skal loades eksplicit når en enkelt spec-fil køres isoleret med ´bundle exec rspec spec/unit/user_spec.rb´ 
— hele suiten loader det automatisk via ´spec_helper.rb´
- BCrypt salter automatisk hver hash, hvilket betyder at samme password aldrig producerer samme hash to gange — unit 
testen beviser dette eksplicit
- Rack::Test simulerer HTTP in-process, hvilket gør integrationstests hurtigere end rigtige netværkskald men stadig 
tættere på virkeligheden end rene unit tests


------

## Implementering af contract tests

### Context
Læreren har defineret en OpenAPI-spec som appens API-endpoints skal leve op til. Contract tests verificerer automatisk at vores responses matcher denne kontrakt — både statuskoder, content-types og JSON-strukturer.

### Challenge
- Committee gem understøtter ikke OpenAPI 3.1 (lærerens spec-version)
- Committee::Test::Methods er designet til Rails/minitest — ikke RSpec med Rack::Test
- Løsning: downgrade spe c til 3.0.0 i lokal kopi + manuel schema-validering for JSON-endpoints

**Overvejede patterns:**
- Committee gem med `assert_response_schema_confirm` — fejlede pga. OpenAPI 3.1 og Rack::Test inkompatibilitet
- Schemathesis (Python) — fravalgt da det er et Python-værktøj i et Ruby-projekt

### Choice
**Beslutning:**
- Committee gem bruges til at loade og parse OpenAPI-spec
- `Committee::Test::Methods` er inkluderet men `assert_response_schema_confirm` erstattes med manuelle RSpec-assertions da metoden forudsætter Rails-miljø
- HTML-endpoints valideres med content-type og statuskode
- JSON-endpoints valideres mod OpenAPI-specens schema-nøgler (AuthResponse, SearchResponse, HTTPValidationError)
- Lokal kopi af spec downgradet fra `3.1.0` til `3.0.0` for Committee-kompatibilitet

**Implementering:**

```bash
bundle exec rspec spec/integration/contract_spec.rb
```

**Rationale:**
- Contract tests sikrer at appen lever op til den fælles API-kontrakt defineret af læreren
- Manuel validering mod spec-nøgler giver samme sikkerhed som Committee's automatiske validering for denne specs kompleksitet
- OpenAPI 3.0 er bagudkompatibel med 3.1 for alle felter brugt i lærerens spec

**Fordele:**
- Ingen ekstern afhængighed udover Committee gem som allerede er installeret
- Tests kører in-process via Rack::Test — ingen kørende server nødvendig
- Fanger regressionsfejl hvis JSON-strukturen ændres i app.rb

**Ulemper:**
- Committee::Test::Methods bruges ikke fuldt ud — `assert_response_schema_confirm` virker ikke med Rack::Test uden Rails
- Lokal spec-kopi afviger fra lærerens originale 3.1-version
- Manuel validering af nøgler er ikke fuldt automatisk — nye felter i spec opdages ikke automatisk

**Retrospektiv:** *(Opdateres løbende)*
- Committee viste sig at have flere begrænsninger end forventet — OpenAPI 3.1 support og Rails-afhængighed

**Læring:**
- Committee gem understøtter kun OpenAPI op til 3.0 — tjek altid gem-kompatibilitet mod spec-versionen før implementering
- `include Rack::Test::Methods` skal eksplicit tilføjes i RSpec — det loades ikke automatisk via spec_helper i isolerede filer
- OpenAPI 3.1 vs 3.0 er en minor version-forskel men kan bryde tooling der ikke er opdateret

------

## Security Breach: Forced Password Reset

### Context

En hacker opnåede read access til vores database og fremviste sample user credentials som bevis. Alle brugerpasswords var hashet med MD5 (før bcrypt-migrationen), hvilket gjorde dem sårbare over for rainbow table attacks.

### Challenge

- Alle brugere potentielt kompromitterede — hackeren havde adgang til hele users-tabellen
- bcrypt-migrationen var allerede deployed, men virkede ikke på serveren pga. en `NOT NULL` constraint på `password`-kolonnen
- `migrate_to_bcrypt!` satte `password: nil` efter re-hash, men SQLite afviste det med `NOT NULL constraint failed`
- 1628 ud af 1742 brugere sad stadig på MD5 og kunne ikke logge ind
- SQLite understøtter ikke `ALTER COLUMN` — constraint kan ikke fjernes in-place

### Choice

**Beslutning:** Implementer forced password reset for alle brugere og fix den underliggende database-constraint

**Implementering:**

1. **Fix NOT NULL constraint:** Genskabt users-tabellen uden `NOT NULL` på `password` og tilføjet `force_password_reset`-kolonne (SQLite kræver table recreation for at ændre constraints)
2. **Before-filter guard:** Alle requests fra flaggede brugere redirectes til `/reset-password` (HTML) eller returnerer 403 (API)
3. **Reset-flow:** Bruger vælger nyt password → bcrypt-hash gemmes → flag fjernes → adgang genoprettet
4. **Defensiv kode:** Guard tjekker `respond_to?(:force_password_reset)` så deploy ikke crasher før migrering er kørt

**Rationale:**

- Force reset for ALLE brugere (ikke kun kendte kompromitterede) fordi hackeren havde read access til hele tabellen
- Guard i `before`-filter sikrer at ingen routes kan bypasses
- API-endpoints returnerer 403 i stedet for redirect for at undgå at bryde API-consumers

**Fordele:**

- Alle kompromitterede passwords invalideres
- Brugere tvinges til at vælge nyt password ved næste besøg
- Fixer samtidig bcrypt-migration buggen der blokerede MD5-brugere

**Ulemper:**

- Alle brugere (inkl. ikke-kompromitterede) skal resette password
- Kræver manuel SSH + migration på serveren efter deploy
- Ingen email-notifikation implementeret (brugere ser kun beskeden ved login)

**Læring:**

- Database constraints skal valideres end-to-end, ikke kun i applikationskoden
- SQLite's manglende `ALTER COLUMN` gør schema-ændringer komplekse — et argument for migration til PostgreSQL
- Deploy og database-migrering skal koordineres — defensiv kode forhindrer downtime mellem de to

------

## Database Indexes for Query Performance

### Context

Alle database-queries kørte uden indexes, hvilket betød full table scans på hver forespørgsel. Med 51 pages og 1742 brugere var performance endnu ikke et problem, men indexes er god praksis og forberedelse til skalering.

### Challenge

- Ingen eksisterende indexes ud over SQLite's auto-indexes på `UNIQUE` constraints
- Identificering af hvilke kolonner der faktisk bruges i queries

### Choice

**Beslutning:** Tilføj indexes på `pages.language`, `pages.url` og `pages.last_updated`

**Implementering:**

- Migreringsscript (`db/add_indexes.rb`) med `CREATE INDEX IF NOT EXISTS` — idempotent og sikkert at køre flere gange
- `users.username` og `users.email` har allerede implicit index via `UNIQUE` constraint

**Rationale:**

- `pages.language` bruges i alle søge-queries (`WHERE language = ?`)
- `pages.url` bruges til URL-lookups
- `pages.last_updated` muliggør effektiv sortering efter aktualitet
- `users`-tabellen behøver ikke yderligere indexes

**Fordele:**

- Hurtigere søgninger, specielt ved voksende dataset
- Ingen ændring i applikationskode nødvendig
- Idempotent migration — ingen risiko ved gentagen kørsel

**Ulemper:**

- Marginalt langsommere writes (index-opdatering ved INSERT/UPDATE)
- Minimal effekt på nuværende datamængde

**Læring:**

- Indexes bør planlægges ud fra faktiske query-patterns, ikke gætværk
- `IF NOT EXISTS` gør migrations robuste og re-runnable
- SQLite's auto-index på `UNIQUE` dækker allerede de mest kritiske lookups

------

## SQLite FTS5: Full-Text Search

### Context

Søgefunktionen brugte `LIKE '%query%'` til at finde pages. Dette er langsomt (full table scan, ingen index-brug) og returnerer resultater i vilkårlig rækkefølge uden relevansrangering.

### Challenge

- `LIKE` med leading wildcard (`%query%`) kan ikke bruge indexes
- Ingen relevansrangering — brugere får resultater i tabel-rækkefølge
- Multi-word søgninger matcher kun som substring, ikke som individuelle termer

### Choice

**Beslutning:** Implementer SQLite FTS5 (Full-Text Search 5) som erstatning for LIKE

**Implementering:**

1. **FTS5 virtual table:** `pages_fts` med `title` og `content` kolonner, synkroniseret via `content='pages'`
2. **Triggers:** `AFTER INSERT`, `AFTER DELETE` og `AFTER UPDATE` triggers holder FTS5-tabellen synkroniseret automatisk
3. **Query-ændring:** Erstattet `WHERE content LIKE ?` med `INNER JOIN pages_fts ... WHERE pages_fts MATCH ?` og `ORDER BY pages_fts.rank`
4. **Begge endpoints opdateret:** Både HTML (`GET /`) og API (`GET /api/search`) bruger FTS5

**Rationale:**

- FTS5 er built-in i SQLite (kræver version ≥ 3.9.0) — ingen eksterne dependencies
- `MATCH` operatoren er markant hurtigere end `LIKE` med wildcards
- `rank` giver automatisk relevansrangering baseret på BM25 algoritmen
- Triggers sikrer at FTS5-tabellen altid er i sync uden applikationslogik

**Fordele:**

- Relevansrangerede søgeresultater
- Bedre performance ved voksende datamængde
- Understøtter avanceret søgesyntaks (phrase search, boolean operators)
- Transparent for eksisterende API-consumers (samme response format)

**Ulemper:**

- Ekstra diskplads til FTS5 index
- Marginalt langsommere writes pga. trigger-overhead
- Migration kræver initial population af FTS5-tabellen
- FTS5 er SQLite-specifik — skal reimplementeres ved migration til PostgreSQL (men PostgreSQL har sin egen FTS)

**Læring:**

- Built-in database features (FTS5, indexes) bør foretrækkes over applikationslogik
- Triggers er effektive til at holde derived data i sync
- `content=` parameter i FTS5 undgår data-duplikering — FTS5 refererer direkte til kilde-tabellen

------

## Server Telemetri

### Context
Indsamling af serverens tilstand via terminal-kommandoer for at forstå nuværende performance og identificere potentielle problemer før de bliver kritiske.

### Challenge
- Ingen swap konfigureret — OOMKiller kan dræbe processer uden advarsel
- Memory usage på 57% (479MB af 847MB) med kun 78MB fri
- `dmesg` kræver root-rettigheder — OOMKiller events kan ikke tjekkes som almindelig bruger

### Choice
**Beslutning:**
Telemetri indsamlet manuelt via terminal. Ingen kritiske fejl fundet — men memory og manglende swap er værd at holde øje med.

**Implementering:**
- [ ] Tilføj swap på serveren: `sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
- [ ] Giv adminuser adgang til dmesg: `sudo sysctl kernel.dmesg_restrict=0`

**Kommandoer kørt:**
```bash
top                                    # CPU og processer
uptime                                 # Load average
free -m                                # Memory forbrug
dmesg | grep -i 'killed process'       # OOMKiller events (kræver root)
df -h                                  # Disk forbrug per partition
du -h                                  # Disk forbrug per mappe
sudo iftop                             # Netværkstrafik per forbindelse
sudo nethogs                           # Netværkstrafik per proces
```

**Rationale:**
- Swap forhindrer OOMKiller i at crashe processer når memory løber tør
- Serveren er relativt lille (847MB RAM) med Docker og Ruby kørende simultaneously

**Fordele:**
- Swap giver buffer ved memory-spikes
- Billigere end at opgradere VM-størrelse

**Ulemper:**
- Swap på disk er langsommere end RAM — performance forringes ved swap-brug
- Løser ikke grundproblemet hvis memory-forbruget fortsætter med at stige

**Retrospektiv:** *(Opdateres løbende)*
-

**Læring:**
- Ingen swap på en lille VM med Docker er en risiko — OOMKiller kan dræbe containere uden advarsel
- `containerd` + `dockerd` bruger tilsammen ~12% memory konstant
- Azure VMs kommunikerer løbende med `168.63.129.16` (Azures interne health check) — normalt og forventet

------

## KPI (Key Performance Indicators)

### Context
A venture capital fund is considering investing in our project and has requested key performance indicators (KPIs) to evaluate the project's health and growth potential.

### Choice
**Beslutning:**
Undersøg:
- CPU load på server
- Antal brugere
- Pris på infrastruktur: mdr. eller total pris på Azure VM

**Implementering:**

```markdown
ssh ind på server

CPU load på server:
Kommando htop 
- CPU load:     0.7% (measured via htop)
- Load average: 0.00 / 0.00 / 0.00 (1, 5, 15 min)
- RAM usage:    460MB / 848MB (54%)
- Uptime:       4 days

Antal brugere:
sqlite3 /opt/whoknows/data/whoknows.db "SELECT COUNT(*) FROM users;"
- 1770 brugere

Antal aktive brugere:
- /opt/whoknows/data$ sqlite3 whoknows.db ".schema users" viser at vi har følgende kolonner i users-tabellen:
id INTEGER, username TEXT NOT NULL UNIQUE, email TEXT NOT NULL UNIQUE, password TEXT NOT NULL , password_digest TEXT);
- Dvs. ingen time stamp eller last_login kolonne, så vi kan ikke definere "aktive brugere" ud fra databasen alene. 
  
- Derfor brugte vi nginx' access log via Dockers stdout – docker logs henter hvad containeren har printet til skærmen ´docker logs app-nginx-1´:
  Active users (unique IPs):     112
  Average searches per day:      179 requests fra 13/04-14/04
  Login attempts:                195
  - Docker logs gemmer kun logs fra den nuværende container-instans, ikke historisk. 
  
- Note: trafik inkluderer simulator-requests fra kursus-infrastrukturen (python-requests/2.32.3). Rå tal er ikke filtreret.
  
- Bash kommandoer: 
    Unikke IP-adresser: ´docker logs app-nginx-1 | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u | wc -l´
    Antal søgninger: ´docker logs app-nginx-1 | grep "GET /?q=" | wc -l´
    Antal login-forsøg: ´docker logs app-nginx-1 | grep "/login" | wc -l´
    
Pris på infrastruktur:
- Azure VM: pris i alt 120,-
- Forudsigelse for et helt år: 620,-
- Månedlige priser: februar 32,-, marts 61,-, april 27,-
```

**Læring:**
- Efter at have kørt disse kommandoer på serveren:
´docker logs app-nginx-1 | grep "GET /?q=" | wc -l´, 
´docker logs app-nginx-1 | grep "/login" | wc -l´,
´docker logs app-nginx-1 | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u | wc -l´ (unikke IP-adresser)
blev vi opmærksomme på denne gentagne besked (tyder på en angriber):
client intended to send too large body: 10485761 bytes POST / HTTP/1.1

------

## Database Placement: Separat VM vs. Co-located vs. Managed Service

### Context

Som del af migreringen fra SQLite til PostgreSQL (issue #203) skulle vi beslutte hvor databasen skulle køre. Opgaven anbefaler eksplicit at databasen ikke bør ligge på samme VM som applikationen medmindre det kan begrundes.

### Challenge

- VM1 (app-serveren) kører allerede nginx + Sinatra med begrænsede ressourcer (256MB til web, 128MB til nginx)
- PostgreSQL kræver dedikeret memory til shared_buffers, work_mem og connections
- Co-located database ville konkurrere med appen om CPU og memory
- Managed services (Supabase, Neon) tilbyder gratis tiers men introducerer ekstern afhængighed og vendor lock-in

### Choice

**Beslutning:** Dedikeret Azure VM (VM2) til PostgreSQL


**Implementering:**

- VM2 (Standard_B2ats_v2) provisioneret på Azure free tier med statisk IP (20.91.203.235)
- PostgreSQL 16 kører som Docker container med persistent volume
- Firewall: Azure NSG tillader kun port 5432 fra VM1's IP (4.225.161.111)
- Database-level sikkerhed: `pg_hba.conf` begrænser adgang til app-brugeren fra VM1
- Password håndteret via Docker secrets, ikke environment variables

**Rationale:**

- Ressourceisolering: databasen påvirker ikke app-performance og omvendt
- Cost: Azure free tier dækker en ekstra VM uden ekstra omkostninger
- Kontrol: fuld kontrol over PostgreSQL konfiguration, backup og adgang
- Ingen vendor lock-in sammenlignet med managed services
- Matcher opgavens anbefaling om at separere database fra applikation

**Fordele:**

- Uafhængig skalering af database og applikation
- Mindre attack surface — database port kun åben for app-serveren
- Lettere at migrere til managed service senere hvis nødvendigt

**Ulemper:**

- Mere ops-overhead: vi skal selv håndtere backup, opdateringer og monitoring
- Netværkslatency mellem VM1 og VM2 (minimal i praksis, begge i swedencentral)
- En ekstra server at vedligeholde

**Læring:**

- Infrastruktur-som-kode bør overvejes — VM2 blev sat op manuelt, men bør dokumenteres reproducerbart
- Statisk IP er vigtigt for firewall-regler mellem servere

------

## Database Engine: PostgreSQL vs. MySQL vs. NoSQL

### Context

SQLite understøtter ikke concurrent writes, hvilket er problematisk for en webapplikation med multiple samtidige brugere. Valget af ny database blev diskuteret i GitHub Discussion #226.

### Challenge

- Applikationen har et simpelt datamodel (to uafhængige tabeller: `users` og `pages`)
- Full-text search er en kernefunktion der kræver god FTS-understøttelse
- Concurrent writes fra simulatoren og rigtige brugere crasher SQLite
- NoSQL ville kræve ny datamodel og miste ACID-garantier for authentication

### Choice

**Beslutning:** PostgreSQL

**Rationale (fra Discussion #226):**

- Allerede en SQL-database — minimal migration fra SQLite
- ACID-garantier for password-håndtering og bruger-unikhed
- Bedre concurrent write-håndtering end MySQL's default locking
- Built-in full-text search via `tsvector` erstatter SQLite FTS5
- ActiveRecord understøtter PostgreSQL med én linje ændring i `database.yml`

**Overvejet men fravalgt:**

- **MySQL:** Svagere FTS, Oracle-ejerskab giver open source-bekymringer
- **NoSQL (MongoDB):** Overkill for to simple tabeller, ingen ACID, unikhedsconstraints skal håndteres i kode

**Læring:**

- Valg af database bør baseres på data-modellen og kravene, ikke personlig præference
- NoSQL-erfaring er bedre at opnå i en kontekst hvor det giver mening

------

## ORM: Behold ActiveRecord vs. Raw SQL

### Context

Instruktøren anbefalede at droppe ORM'en givet den simple datamodel. Diskuteret i GitHub Discussion #228.

### Challenge

- ActiveRecord er designet til Rails og føles tungt for en standalone Sinatra-app
- Kun to simple tabeller uden joins — ORM-abstraktionen udnyttes ikke fuldt
- At skifte til raw SQL kræver omskrivning af eksisterende modeller og migrationer uden funktionel gevinst

### Choice

**Beslutning:** Behold ActiveRecord — en pragmatisk beslutning, ikke en teknisk

**Rationale:**

- Omskrivning har reel arbejdsomkostning med nul funktionel forbedring
- ActiveRecord gør database-adapter-skiftet til en config-ændring (sqlite3 → postgresql)
- Rake migrations er allerede sat op og integreret
- Tiden bruges bedre på højere-prioritets issues

**Vigtigt:** Vi argumenterer ikke for at ActiveRecord er det rigtige tekniske valg. Vi argumenterer for at omkostningen ved at skifte overstiger fordelen på dette tidspunkt i projektet.

**Læring:**

- Teknisk korrekthed vs. pragmatisme er en reel afvejning i softwareudvikling
- At dokumentere *hvorfor* man træffer et suboptimalt valg er lige så vigtigt som valget selv

------

## Migration Tool: Rake vs. Flyway vs. Manual SQL

### Context

Valg af migrationsværktøj afhænger af ORM-valget. Diskuteret i GitHub Discussion #229.

### Choice

**Beslutning:** Rake migrations (følger af ActiveRecord-valget)

**Rationale:**

- Allerede sat op i projektet — ingen ny tooling nødvendig
- Integreret med ActiveRecord modeller
- Flyway kræver JVM runtime — for tungt en afhængighed for migrering alene
- Manuel SQL scripts giver ingen versionering eller rollback

**Læring:**

- Migrationsværktøj bør følge ORM/database-valget, ikke omvendt

------