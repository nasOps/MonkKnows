


## Cyklomatisk kompleksitet

Cyklomatisk kompleksitet tæller antallet af uafhængige stier gennem koden — hver `if`, `elsif`, `case`, `while`, `&&` og `||` tilføjer 1.

| Fil | Cyklomatisk kompleksitet |
|-----|--------------------------|
| `ruby-sinatra/app.rb` | 60 |
| `azure-function/function_app.py` | 31 |
| `ruby-sinatra/services/weather_service.rb` | 11 |
| `scripts/migrate_sqlite_to_pg.rb` | 10 |
| **Total** | **155** |

`POST /api/pages` illustrerer problemet: routen indeholder fem separate forgreningspunkter (autentificering, to valideringer, filtrering og duplikatfjernelse), der hver tilføjer en ny sti gennem koden. Det samlede tal for `app.rb` afspejler derudover at mange routes og forretningslogik er samlet ét sted — et klassisk Sinatra-mønster.

Sinatra pålægger ingen struktur for opdeling af routes og forretningslogik — i modsætning til Rails, der tvinger én controller per resource. Vi valgte bevidst at samle al logik i `app.rb`, da applikationen var lille og en fladere struktur virkede passende. Vi blev opmærksomme på kompleksitetsmålingerne for sent i forløbet til at en større omstrukturering var realistisk.

## Kognitiv kompleksitet

Kognitiv kompleksitet måler, hvor svær koden er at læse og forstå — i modsætning til cyklomatisk kompleksitet straffer den dyb nesting hårdere end simpel forgrening.

| Fil | Kognitiv kompleksitet |
|-----|----------------------|
| `ruby-sinatra/app.rb` | 71 |
| `azure-function/function_app.py` | 26 |
| `scripts/migrate_sqlite_to_pg.rb` | 6 |
| **Total** | **127** |

Den høje score i `app.rb` skyldes primært at `POST /api/pages` har tre separate ansvar i én route: autentificering, validering og dataindsættelse. `before`/`after`-hooks og `track_user_activity` bidrager yderligere med nestede betingelser og rescue-blokke, der er vokset over tid.

Den korrekte løsning ville være at udtrække disse ansvar i dedikerede service-objekter. Dette er blevet nedprioriteret til fordel for at levere features og infrastruktur inden for projektets tidsramme.
