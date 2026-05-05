


## Cyklomatisk kompleksitet

Cyklomatisk kompleksitet tæller antallet af uafhængige stier gennem koden — hver `if`, `elsif`, `case`, `while`, `&&` og `||` tilføjer 1.

| Fil | Cyklomatisk kompleksitet |
|-----|--------------------------|
| `ruby-sinatra/app.rb` | 60 |
| `azure-function/function_app.py` | 31 |
| `ruby-sinatra/services/weather_service.rb` | 11 |
| `scripts/migrate_sqlite_to_pg.rb` | 10 |
| **Total** | **155** |

Den høje score i `app.rb` skyldes primært at mange routes og forretningslogik er samlet ét sted — et klassisk Sinatra-mønster. Individuelle metoder holder sig under grænsen på 10-15, så kompleksiteten er fordelt frem for koncentreret.

Opdeling i mindre controllers eller service-objekter ville reducere tallet, men er nedprioriteret inden for projektets tidsramme.

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
