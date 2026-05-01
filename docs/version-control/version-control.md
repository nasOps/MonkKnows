# Version Control

## Versionering
Vi har brugt semantisk versionering som overordnet ramme, men ikke fulgt den konsekvent. Vores releases har i højere grad været styret af følelser omkring et release end af SemVers regler for MAJOR, MINOR og PATCH. Vi har eksempelvis tagget v2.0.0 ved tilføjelsen af PostgreSQL og en crawler — pure tilføjelser uden breaking changes, som rettelig burde have været en MINOR. Resultatet er manglende transparens omkring vores releases, hvor brugeren ikke kan aflæse hvilken version der er stabil.

### Semver-analyse

Hvis vi havde fulgt strikt semver fra v1.0.0 ville vi ligge på **~v1.3.0** i dag (vi ligger på v2.0.0).

#### Hvor vi overshootede

| Tag | Reel klassifikation |
|---|---|
| v1.2.0 — "Trunk-Based Dev" | Workflow-skift, ikke en version-bump værd |
| v1.3.0 — "Security & Hardening" | Mest PATCH/MINOR — kun FTS5 var rigtig MINOR-værdig |
| v2.0.0 — "PG + Crawler" | Pure tilføjelser, ingen breaking changes → MINOR |

### Den eneste rigtige MAJOR-kandidat siden v1.0.0

PR #222 (forced password reset) returnerede 403 for tidligere-200 endpoints. Lærebogs-MAJOR — men kolonnen blev droppet igen, så det var midlertidigt.

---

## Branching Strategy
- Vi startede med at bruge en tilpasset version af Gitflow med development som integrations/staging branch. Ud fra denne oprettede vi feature-branches direkte fra GitHub issues, og lavede PRs til development. Når development var stabil, lavede vi en PR til main.
- Da vi oplevede at udviklingen i development løb langt foran main, og at merges til main blev store og risikable, skiftede vi til trunk-based development. Nu laver vi PRs direkte til main, og development er kun en read-only archive branch.
- Vi skiftede derfor fra Gitflow til Trunk-based development. Således reduceres lead time for features, og vi får hurtigere feedback på PRs. Vi skulle dog øve os i at holde PRs små og selvstændige, da de nu går direkte til produktion. Gevinsten var derudover, at bugs var lettere at lokalisere, fordi vi ikke mergede store chunks af kode.
  ang. CI/CD/CD/CF

Vi har i forbindelse med CI/CD oprettet rigtigt mange workflows, nogle e2e, et build workflow, nogle test, noget flere CD's og lign.


Formålet var, at alle steps var inddelte og vi derfor havde et hurtigt overblik.

Dog har vi senere været nødsaget til, at indele det i kategorier, såsom CI/CD/CD/CF som en del af at være transparent. Vi har forsøgt, at gøre det synligt for den uindviet, at se hvad der gør hvad, og hvor hvilket hører til.

Ingen secrets i image, ingen secrets i repo. CD-workflowet bygger .env fra GitHub secrets og SCPer den til serveren ved hver deploy. Det giver:

Adskillelse af kode og hemmeligheder (kan rotere uden redeploy af kode)
Ingen risiko for accidental commit af hemmeligheder
Mulighed for at forskellige miljøer har forskellige værdier uden kode-fork
Det vi ikke har — og hvorfor - Ingen manuel approval-gate på CD. Trade-off: hurtigere flow, men ingen "sidste-chance" før prod. Kompenseret af PR-review og smoke tests. Acceptabelt for et kursusprojekt; tvivlsomt til ægte enterprise.                       - Ingen separat staging-miljø. Trunk-based dev sender direkte til prod. Vi opfanger fejl med smoke tests og rollback-via-tag, ikke med staging.
Ingen rolling deploys / blue-green. Containere stoppes og genstartes; nedetid håndteres af Docker-healthcheck + --wait (PR #277). Blue-green var option #4 i
deploy-MTTR-analysen — fravalgt som for tungt.

Vi har brugt følgende features fra GitHub: issues, labels, milestones, discussions, PRs og projects som et kanban board.
Issues er oprettet med relevante tags og labels, hvilket understøtter Collaboration and Communication (uge 4) ved at gøre arbejdsopgaver synlige og veldefinerede for hele gruppen.
Milestones har vi brugt til mandatory-opgaver, adskilt fra projects-boardet, da de ikke har noget med selve udviklingsprocessen at gøre. Det holder kanban-boardet fokuseret og reducerer støj — i tråd med Value-stream Mapping og LEAN (uge 10): identificer det der skaber værdi, og skær resten væk.
Discussions har vi brugt til at vende idéer og samle løse tanker — "det her skal vi også lige huske". Det er et direkte udtryk for Transparency, visibility and knowledge sharing (uge 2): i stedet for at idéer forsvinder i en Messenger-tråd, lever de et offentligt sted i repoen.
PRs har vi konsekvent oprettet gennem hele projektforløbet, hvor diskussioner, spørgsmål og forslag er holdt som kommentarer. Det bryder informationssiloer ned (uge 2) og giver et naturligt alternativ til statusmøder — Collaboration and Communication (uge 4) nævner netop: instead of a daily standup meeting → daily PR?
Som en del af kommunikationsplanen har været på tværs af flere platforme, efter nemhed. Det vigtigere for vidensdelingen i teamet, at der der bliver vidensdelt, og det kan gøres hurtigt gennem discord, sms, messenger eller andet frem, for det skulle være en chore at vidensdele gennem github, i prædefineret formater og sprog.

Actions: automatiserer tests og deployment (CI/CD).

Branches blev brugt til at arbejde på nye features udem at påvirke hovedkoden på main, fordi branchen er en parallel kopi af denne.

Vi søgte at lave små commits for at skabe transparens omkring ændringer, så disse kunne ses i historikken som et snapshot af filerne på et givent tidspunkt.
