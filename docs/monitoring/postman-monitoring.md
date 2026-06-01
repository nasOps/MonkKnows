# Postman Monitoring — MonkKnows

_Sidst opdateret: 2026-05-21_

Postman bruges til manuel end-to-end API-verifikation mod produktion (`https://monkknows.dk`). Collectionen hedder **MonkKnows** i Postman-workspacet **MonkKnows** (`nasops.postman.co`).

**Seneste run:** 47/47 tests grønne (2026-05-21, Manuel Runner).

---

## Collectionen

8 endpoints, 47 assertions i alt:

| Endpoint | Metode | Tests |
|---|---|---|
| `/?q=string&language=en` | GET | Status 200, response time < 5s, Content-Type html, body ikke tom |
| `/weather` | GET | Status 200, response time < 5s, Content-Type html, body ikke tom |
| `/register` | GET | Status 200, response time < 5s, Content-Type html, body ikke tom |
| `/login` | GET | Status 200, response time < 5s, Content-Type html, body ikke tom |
| `/api/search?q=string` | GET | Status 200, `data`-array tilstede og ikke tomt, hvert item har korrekte felter, response time < 5s |
| `/api/weather` | GET | Status 200, `data`-objekt med `city`, `temperature`, `humidity`, `condition`, `wind_speed`, `source` — korrekte typer, response time < 5s |
| `/api/register` | POST | 200 ved valid input (statusCode + message), 422 ved validationsfejl |
| `/api/login` | POST | 200 + `rack.session`-cookie sat ved korrekt login, 422 ved forkert password/username |
| `/api/logout` | GET | Status 200, JSON-body med message |

---

## Konfiguration

**baseUrl:** `https://monkknows.dk` (sat som collection-variabel i Postman Cloud)

**Scheduled monitor:** Ikke aktiv. Var slået til i starten af kurset, men deaktiveret fordi automatiske alerts var støjende mens systemet stadig var under aktiv udvikling.

---

## Kør manuelt

1. Åbn [nasops.postman.co](https://nasops.postman.co) → workspace **MonkKnows** → collection **MonkKnows**
2. Klik **Run** øverst til højre
3. Klik **Run MonkKnows** i Collection Runner
4. Gennemgå resultater — alle 47 tests bør være grønne mod produktion

---

## Historik og kendte fejl

**Fejl maj 2026 (2 fejl i 4 runs):** `baseUrl`-variablen var sat forkert, hvilket betød at visse requests fejlede på connection-niveau og ikke nåede assertions. Rettet 2026-05-21 — 47/47 grønne herefter.

**Fejl marts–april 2026:** `POST /api/login` returnerede 200 men `rack.session`-cookien var aldrig sat — Postmans cookie-test fejlede konsekvent. Rodårsag: nginx forwardede ikke `X-Forwarded-Proto`-headeren til Sinatra, så Rack droppede den sikre session-cookie lydløst. Rettet i PR #256.

---

## Genaktivér scheduled monitoring

Hvis man ønsker planlagte runs mod produktion igen:

1. Åbn collectionen → fanen **Runs** → **Scheduled**
2. Klik **+ Schedule a run**
3. Vælg interval (anbefalet: dagligt eller ugentligt — ikke hvert 5. minut som tidligere)
4. Vælg region tæt på serveren (EU West)
5. Sæt alerts til kun at notificere ved fejl (ikke ved hvert run)
