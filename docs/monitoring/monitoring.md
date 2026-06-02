# Monitoring Realization

> *"The end-goal of monitoring is to make you see a new dimension of your system."*

Det her er en samling af de øjeblikke hvor monitoring rent faktisk viste os noget vi ikke vidste — og hvor indsigten ledte til en konkret ændring. Vi har valgt at fortælle det som tre faser, fordi rejsen gik *udefra og ind*: først var det Anders' plot-server der viste os at vi fløj i blinde lokalt, så var det diskrepansen mellem plot-serverens fejlsignal og vores egne logs der afslørede en længe-skjult bug, og til sidst — da vi havde bygget vores egen Grafana — afslørede vores eget dashboard en helt klasse af problemer vi slet ikke havde tænkt på.

---

## Fase 1 — Vi opdagede at vi fløj i blinde

Vores første "monitoring realization" var paradoksalt nok en realisering om *manglen* på monitoring — og den kom udefra, ikke fra noget vi selv havde bygget.

`/api/login` og `/api/register` returnerede 422 fra første deploy den 26. februar. Det var **Anders' plot-server** (simulatorens fejlfeed på `158.158.49.35:8000`) der hele tiden viste fejlene — vi havde bare ikke selv noget der kiggede på det, og signalet var ikke gjort centralt nok i vores hverdag til at vi tog det alvorligt. Det vi havde lokalt var Postman-baseret health-monitoring der svarede ja/nej på "kører appen overhovedet?", og en health-endpoint kan svare 200 hele dagen mens hver eneste rigtig request fejler.

Da det gik op for os, gik to ting op for os samtidig: dels at "appen kører" og "appen virker" er to forskellige spørgsmål, dels at vi ikke kunne forblive afhængige af lærerens plot-server som vores eneste reelle observability — vi var nødt til at bygge vores egen så vi *selv* kunne se status code-fordelingen i stedet for at vente på et eksternt signal.

**Fix:** Indsigten ledte direkte til monitoring-stacken (Prometheus på VM2:9090, Grafana på VM2:3000) med `http_server_requests_total{code, method, path}` som første prioritet. Stacken er siden vokset til **to dashboards med 27 paneler i alt** og 90 dages metrics-retention i Prometheus' TSDB:

- **"MonkKnows — User Telemetry"** (9 paneler) — produktvinkel: registrerede brugere, søgninger, zero-result-søgninger, DAU/WAU/MAU, churn-proxy, søgeresultat-distribution
- **"MonkKnows — Operations"** (18 paneler) — drifts-vinkel: request rate per endpoint, latency p50/p95/p99/p99.9, 4xx/5xx fejlrater, top exception-klasser, bot-/scanner-trafik på non-app routes, Weather API latency/errors, og host-metrics (CPU, RAM, disk, netværks-I/O) via `node_exporter` på begge VMs

Det datagrundlag vi manglede er nu dækket fra både applikations- og OS-laget.

---

## Fase 2 — En diskrepans mellem to signaler afslørede en bug brudt siden HTTPS-setup

Også denne realisering kom fra plot-serveren — men det interessante var ikke signalet i sig selv, men **diskrepansen** mellem det og vores egne logs.

Plot-serveren rapporterede dagligt `e2e_error:can_log_in`. Samtidig viste vores egne app-logs at `/api/login` returnerede 200 OK på de samme requests. To kilder, samme request-flow, modstridende konklusion: simulatoren kunne ikke logge ind, men appen sagde at login lykkedes. Det gav ingen mening — og det var præcis den slags spørgsmål man kun kan stille hvis man har *flere* observability-vinkler at sammenligne.

Da vi gravede i det viste det sig at login-svaret manglede `Set-Cookie`-headeren. Autentificeringen virkede teknisk set, men sessionen blev aldrig sendt tilbage til klienten, så hver efterfølgende request var anonym. Bug'en havde sandsynligvis været brudt siden HTTPS blev sat op — uger, måske måneder, hvor ingen rigtig bruger nogensinde havde været logget ind på tværs af to sider.

Det var et øjeblik hvor vi virkelig forstod hvorfor man bygger monitoring: manuel testning fanger ikke den slags. Vi kan teste login lokalt og se det "virke", fordi vi følger samme request-cycle som simulatoren — 200 OK, redirect, færdig. Men i produktion, over HTTPS, bag nginx, var cookien tabt, og det havde ingen af os opdaget før vi sammenholdt plot-serverens fejlfeed med vores egne logs og spurgte: hvordan kan begge være rigtige?

**Fix:** Session-cookie konfigurationen blev rettet så `Set-Cookie` faktisk sendes med over HTTPS. Simulatorens `can_log_in`-fejl forsvandt fra plot-serveren samme dag (baseline gik fra 120 fejl til 3 efter PG-deploy + cookie-fix).

---

## Fase 3 — Dashboardet afslørede problemer vi slet ikke havde tænkt på

Den tredje og største realisering kom efter dashboardet havde kørt et stykke tid og vi begyndte at kigge på det "for sjov" — uden et bestemt spørgsmål i hovedet.

Vi opdagede at en betydelig del af vores trafik ikke kom fra hverken brugere eller simulatoren. Serveren blev konstant scannet af automatiserede bots der ledte efter eksponerede credentials — `.env`, `.aws/config`, `.git/config`, `/wp-admin`, `/phpmyadmin`, og lignende. Det var hverken et angreb i klassisk forstand eller noget der brød appen, men det fyldte i metrics og forvrængede billedet af hvad "rigtige" requests så ud som.

Det var præcis den slags indsigt Anders pegede på i timen: *"It's an impressive sign if your setup makes you realize something that helps you improve your system."* Vi havde bygget monitoreringen for at få styr på vores egne fejl — i stedet viste den os en hel kategori af interaktioner med systemet vi ikke havde tænkt eksisterede.

**Fix:** Vi indførte whitelist-filtrering på dashboardets endpoint-baserede paneler i stedet for blacklist. For et offentligt eksponeret system er whitelist det eneste robuste valg — der findes uendeligt mange paths bots vil prøve, men kun en håndfuld vi rent faktisk eksponerer. Det gjorde dashboardet brugbart igen og gav os samtidig en nyttig gratis-indsigt: vi har en lang hale af sikkerhedsrelevant trafik vi ellers aldrig ville have set.

---

## Mindre realiseringer

Ud over de tre store er der nogle mindre opdagelser, som er værd at nævne:

- **Tomme paneler er også et signal.** DAU/WAU/MAU og `response_size`-panelerne stod tomme et stykke tid før vi opdagede det. Det var et "monitoring monitorerer monitoring"-øjeblik: dashboardet skal tjekkes ind imellem, ikke bare bygges. Fixet i PR #271 (commit `316e6ca`).

- **Healthcheck er fail-fast for "kører containeren?", ikke "er appen klar?".** CD-pipelinens smoke-test fejlede sporadisk fordi `docker compose --wait` returnerer så snart containeren er *running*, ikke når Puma faktisk lytter. Vi tilføjede en rigtig healthcheck til prod-compose med `start_period: 300s` og lod `--wait` blokere på det (PR #277). Deploy-MTTR blev mere forudsigelig.

- **Metric labels er ikke selvforklarende.** `prometheus-client` gem v4.x bruger `code` som label for HTTP-statuskoder, ikke `status`. Det opdagede CodeRabbit ved et review *efter* dashboardet var bygget — alle PromQL queries skulle rettes. Lærdommen: tjek `/metrics`-output direkte før der bygges queries oven på.

- **Manuel server-telemetri afslørede manglende swap.** Før Prometheus var oppe kørte vi en runde manuel telemetri på VM'erne. Ingen kritiske fejl, men VM2 lå på 898 MB RAM uden swap — værd at holde øje med under stress-test ugen før eksamen. Det blinde punkt er siden lukket: `node_exporter` kører på begge VMs og leverer CPU/RAM/disk/netværks-metrics live i Operations-dashboardet, så samme observation i dag ville være automatisk og kontinuerlig i stedet for et øjebliksbillede fra terminalen.

- **Recording rules løste et reelt produktionsproblem.** Operations-dashboardet var ubrugeligt i lange tidsvinduet — latency-paneler tog ~84 sekunder at indlæse fordi `histogram_quantile` genberegnede over ~200 bucket-serier ved hvert datapunkt, hver gang nogen åbnede en visning. PR #316 tilføjede `rules.yml` med forudberegnede percentiler (p50/p95/p99/p99.9) der opdateres hvert 15. sekund, hvilket reducerede indlæsningstiden til millisekunder. Prometheus var samtidig i OOM crash-loop (54 restarts, bekræftet i `dmesg`) og resource limits måtte hæves fra 256m til 1024m. Begge problemer skyldtes at vi ikke havde stresstet dashboardet over et langt tidsvindue inden det gik i produktion — "det ser fint ud lokalt" gælder ikke for systemer der akkumulerer data over tid.

---

## Hvad monitoreringen *ikke* gør (endnu)

Refleksionen bliver mere ærlig af også at sige hvad vi *ikke* har på plads:

- **Ingen Alertmanager / ingen alert-regler.** Prometheus indsamler data, Grafana visualiserer det — men ingen sender besked når noget går galt. Vi *opdager* problemer ved at kigge på dashboardet, ikke ved at få et signal. I et rigtigt produktionsmiljø ville det her være første mangel at lukke. Det vi har som nødløsning er `monitor_logs.sh` på VM1 der scanner container-logs hvert 5. minut og sender Discord-webhooks ved `4xx`/`5xx`-mønstre — men webhook-URL'en er hardkodet i scriptet, så det er ikke en holdbar løsning.

- **Grafana eksponeret på plain HTTP (port 3000).** Bevidst valg ved opsætningen — vi ville gøre dashboardet tilgængeligt uden SSH-tunnel — men det betyder at credentials sendes ukrypteret. Det rigtige setup ville være nginx reverse proxy + TLS foran, eller en managed Grafana. Vi har sikret det vi kunne på Grafana-niveau (krævet brugernavn/password, signup deaktiveret, anonym adgang deaktiveret), men ikke på transport-niveau.

---

## Den ærligste realisering: vi byggede det alt for sent

Hvis vi skal pege på *én* indsigt der står over alle andre, er det ikke en specifik bug eller et konkret fund fra et panel — det er at vi byggede hele monitoring-laget alt for sent. Dashboardet kom op et par uger før eksamen, ikke fra dag ét. Det betyder i praksis at vi **ikke ved hvad der er sket løbende** i systemet gennem semesteret:

- Hvor mange registreringer fejlede i marts?
- Hvor lang tid tog en søgning i februar?
- Hvor mange 5xx'ere fløj forbi i ugen efter PostgreSQL-migrationen?
- Hvor længe havde cookie-bug'en faktisk været brudt?

Vi kan ikke svare. Prometheus' 90-dages retention dækker kun fra det tidspunkt stacken blev deployet — alt før det er tabt, og det er størstedelen af projektets levetid.

Endnu mere fundamentalt: indtil sent i forløbet havde vi heller ikke selv *tanken* om at det her var noget vi skulle. Monitoring stod på pensum som "session 11", ikke som noget der vokser sammen med systemet fra dag ét. Det er i sig selv en monitoring-realisering — at man ikke kan retro-fitte indsigt i en produktions-historik. De data man ikke indsamler, er tabt for altid. Det er et reelt minus i vores DevOps-praksis (også taget op under DevSecOps i `how-are-we-devops.md` uge 9), og det er den enkelte ting vi vil gøre fundamentalt anderledes næste gang: monitoring er ikke et lag man hænger på til sidst, det er noget der bør være på plads samtidig med at den første endpoint går i produktion.

---

## Hvad vi tager med

Den røde tråd er at monitoring ikke bare er et "bevis" på at systemet kører. Det er en linse der gør et eksisterende system synligt på en måde det ikke var før. Hver af de tre faser ovenfor afslørede noget vi *havde levet med uden at vide det* — en stille bug, en hel klasse af trafik, eller bare det grundlæggende fravær af signaler. Det er den dimension Anders' citat handler om, og det er først nu vi rigtig forstår hvad han mente.

Den hårde version af samme indsigt er sektionen ovenover: vi forstod først linsen efter vi byggede den, og vi byggede den så sent at det meste af projektets liv er forsvundet ud af synsfeltet. Næste gang starter den linse-bygning på dag ét.
