# Choices and Challenges

**Written by:** Andreas, Nima & Sofie
 **Updated:** 15th February 2026 - 09.52

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

---

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

---

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

---

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