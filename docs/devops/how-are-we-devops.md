# DevOps principper — MonkKnows

## Uge 1 — Continuous Improvement and Learning / Culture of Collaboration and Shared Responsibility

### Continuous Improvement and Learning

Vores forbedringer er sket løbende og naturligt gennem projektet. Vi har ikke lavet noget perfekt fra starten — vi har været nødsaget til konstant at bygge videre på det vi havde, og på den måde har forbedring været en indbygget del af arbejdsprocessen. Et konkret eksempel er migreringen fra SQLite til PostgreSQL, samt vores workflows, som har været i konstant udvikling gennem hele forløbet.

Læringen har som udgangspunkt været planlagt via undervisningen, men det vi selv har taget ejerskab over er, hvordan vi har valgt at bruge og udfordre det materiale vi er blevet præsenteret for. Når det har været nødvendigt, har vi oprettet relevant dokumentation for at samle viden og læring ét sted — noget der i sig selv afspejler en forbedring i den måde vi håndterer og deler information på. Choices & Challenges-dokumentet har vi brugt aktivt under hele projektet til at dokumentere udfordringer, overvejelser og løsninger, så refleksionen ikke forsvinder.

### Culture of Collaboration and Shared Responsibility

Issues har været et fællesansvar at løse løbende, uanset hvem der oprettede dem. Samarbejdet har foregået via GitHub discussions, PR-kommentarer og andre kanaler som Discord og en fælles iMessage-tråd, hvor vi under hele projektet har holdt en åben dialog. Det har betydet at fremdriften ikke har hængt på én person, men har været fordelt, så der altid har været nogen til at løfte.

Med kun tre personer i gruppen har delt ansvar i praksis været en nødvendighed, men det er også noget vi alle er gået bevidst ind i. En del af vores dokumenter har fungeret som et "place of truth" — hvis noget ændrede sig, skulle de opdateres, hvilket har sikret at alle har haft det samme udgangspunkt og forstærket samarbejdet.

---

## Uge 2 — Transparency, Visibility and Knowledge Sharing

Vi har været transparente ved at holde størstedelen af vores diskussioner på GitHub — under issues, i PR-kommentarer, code reviews og discussions. Commit-historikken viser vores progress og er offentligt tilgængelig. Vi har delt viden via docs og de nævnte kanaler, og vi har oprettet en README. Vi har desuden templates til både issues og PRs, som sikrer en ensartet struktur og gør det nemt at forstå konteksten for et givent stykke arbejde.

På den måde har vi aktivt arbejdet på at bryde informationssiloer ned og gjort vores arbejde synligt — både for hinanden og for udefrakommende.

---

## Uge 3 — Reduce WIP (Work In Progress)

**Avoid large batch sizes**
Vi har forsøgt at håndtere dette ved at holde issues små og fokuserede. Da vi senere overgik til en trunk-based branching-strategi, fik vi et mere kontinuerligt og roligt flow, som reducerede lead time og gjorde det lettere at holde batch sizes nede.

**Limit active branches**
Da vi startede med en feature/development branch-strategi, havde vi en tendens til ikke at slette branches — en nervøsitet for at miste noget, hvis der fejlede. I takt med at vi overgik til trunk-based og vores workflows blev mere robuste, forsvandt behovet for at holde branches i live.

**Merge to trunk at least daily**
Det har vi ikke levet op til. Vi arbejder ikke på faste tidspunkter konsekvent, men når det har givet mening for os, og det har medført uregelmæssigheder i forhold til dette princip.

**Avoid long-lived branches**
Det var vi dårlige til i starten, indtil Andreas satte automatisk sletning af branches op ved merges, hvilket løste problemet.

---

## Uge 4 — Collaboration and Communication

**Make PRs of a readable size**
Det er meget få PRs der har været lange — og når de har været det, har det typisk afspejlet at opgaven var større og krævede det. Vores PRs har fulgt en fast skabelon, hvor den reelle værdi har ligget i listen over changes made. Har der været behov for mere kontekst, er det landet i Choices & Challenges fremfor at fylde PRen op. PRs har desuden indeholdt relevante kategorier, information om hvordan der er testet, og hvordan man selv kan teste — hvilket har gjort dem nemme at læse og reviewe.

**Instead of a daily standup → daily PR?**
Vi har primært brugt Discord og en fælles iMessage-tråd til daglige check-ins, når det har været nødvendigt, fremfor formelle standups.

---

## Uge 5 — Fail Fast, Recover Fast

Vi har bygget en pipeline der fanger fejl tidligt, så vi ikke opdager dem i produktion. Det sker via en række tools integreret i vores workflows: Rubocop til linting, Bundler Audit og Trivy til sikkerhedssårbarheder i dependencies og images, Hadolint til Dockerfile-analyse, OWASP til sikkerhedsscanning af den kørende applikation, og smoke tests der verificerer at applikationen starter korrekt efter deploy. CodeRabbit er desuden integreret som AI-drevet code review direkte i PRs.

Tilsammen betyder det at vi fejler hurtigt og lokalt — og dermed kan recovere hurtigt.

---

## Uge 6 — The A in CALMS: Automate Everything

Vi har automatiseret en bred vifte af processer for at fjerne friktion og gøre arbejdet lettere. PR-merges trigger automatisk lukning og sletning af branches. Issues rykker automatisk til "Done" i vores kanban-board. Vi har en fuld CI/CD/CD/CF-pipeline. Pre-commit hooks kører Rubocop inden et commit kan laves. Postman er sat op til monitoring. Det samlede resultat er at manuelle og gentagne opgaver i høj grad er taget ud af ligningen.

---

## Uge 8 — End-to-End Responsibility

End-to-End Responsibility dækkes i høj grad af det vi allerede har beskrevet under Shared Responsibility og Collaboration. Alle tre gruppemedlemmer har haft en aktiv rolle i både udvikling og drift — ingen har haft eneansvar for hverken Dev eller Ops, og strukturen i projektet har gjort det muligt at løfte på tværs.

---

## Uge 9 — DevSecOps: Secure by Design, Not as an Afterthought

Her har vi ikke levet fuldt op til princippet. Vi stødte på et password-problem, som ikke var tænkt ind i designet fra starten, men opstod som en eftertanke. Vores VM-setup mangler stadig foranstaltninger som fail2ban og lignende, som burde have været med fra begyndelsen.

På applikationsniveau har vi håndteret SQL injection ved at bruge parameteriserede queries, hvilket er et eksempel på at tænke sikkerhed ind i designet. Men samlet set er det et område, hvor vi har lært at sikkerhed skal med fra dag ét — ikke hægtes på til sidst.

---

## Uge 10 — Value-Stream Mapping og LEAN

På det stadie vi er nået til nu, med vores workflows, monitorering og diverse alerts, har det ikke været en udfordring at *finde* bottlenecks — de bliver fanget automatisk. Udfordringen har i stedet været at løse dem løbende når de opstår.

**Reduce waste**
Vi har optimeret CI-kørsler ved at parallelisere jobs, indføre quality gates der stopper pipelinen tidligt ved fejl, cache gems mellem runs med Bundler cache, og sat concurrency op så nye pushes stopper igangværende kørsler og starter forfra. CodeRabbit bidrager også her ved at reducere den manuelle reviewtid.

**Query smart, query fast**
Vi har indekseret databasen for at forbedre query-performance.

---

## Uge 11 — Continuous Feedback

Vi har sat monitorering op, som giver os relevant data om interaktion på siden, performance og andet — et datagrundlag der i princippet muliggør løbende forbedring af produktet. Vi logger desuden specifikke hændelser på vores VMs. Et konkret spørgsmål vi kan stille på baggrund af vores data er: hvad søger brugerne på? — og den slags indsigt er præcis det Continuous Feedback handler om.

---

## Uge 12 — Infrastructure as Code: Repeatable, Reliable, Redeployable

Terraform ville have været det oplagte valg her, men det er ikke noget vi har nået at implementere eller taget endelig stilling til. Det vi kan sige er at vi har elementer af IaC til stede i projektet: Nginx-konfiguration, Docker Compose, GitHub Actions workflows, shell-scripts, run hooks og en infrastructure-map.md.

Vi vurderer at vi sandsynligvis er *redeployable* i dag, men vi er ikke fuldt *repeatable* og *reliable* i IaC-forstand, da de nødvendige foranstaltninger endnu ikke er på plads. Det er her Terraform og Kubernetes ville give reel værdi.

---

## Uge 13 — DevOps is Culture

Vi har i gruppen været bevidste om at DevOps ikke er endnu et procesframework som Scrum — det er en måde at arbejde, samarbejde og tænke på. Fokus har været på at skabe et setup hvor fremdrift, videndeling og forbedring er strukturelt forankret, fremfor afhængigt af enkeltpersoner. Projektet har i princippet den struktur, at et gruppemedlem kunne udskiftes, fordi arbejdsprocessen ikke hviler på individer.

Ser vi det gennem CALMS-linsen:

**Culture**
Vi har haft en åben og løbende dialog, men vi har også haft perioder hvor vi ikke har været gode nok til at løfte i flok, når nogen har været fraværende. Vores tilgang har i for høj grad hvilet på individuelt ansvar, og det vi har lært er, at DevOps-kultur kræver at man aktivt løfter hinanden op — også når det ikke direkte handler om projektet. Det er noget vi er kommet fra tidligere projekter med som en vane, men som ikke fungerer på samme måde i DevOps-konteksten.

**Automation**
Dækket under uge 6.

**Lean**
Dækket under uge 10.

**Measurement**
Vi har ikke været konsistente nok i vores brug af releases og versioning, hvilket har gjort det uklart for os selv og andre, hvad der præcist er deployed hvornår. Det er et transparens- og measurement-problem.

**Sharing**
Vi har haft siloer — PRs har til tider ligget længe uden review, hvilket har blokeret videndeling og fremdrift. Det strider mod princippet om at dele åbent og hurtigt.
