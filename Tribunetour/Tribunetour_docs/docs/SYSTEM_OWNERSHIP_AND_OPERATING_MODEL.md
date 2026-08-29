# Tribunetour System Ownership And Operating Model

Senest opdateret: 2026-08-29

Formålet med dette dokument er at være den praktiske sandhed, når vi arbejder i Tribunetour.

Det er ikke et visionsdokument.  
Det er et drifts- og beslutningsdokument.

Hvis vi bliver i tvivl om:
- hvilket repo vi skal ændre i
- hvad der er source of truth
- hvordan en ændring slår igennem
- hvorfor noget ser rigtigt ud ét sted og forkert et andet sted

så er det dette dokument, vi starter i.

## 1. Det vigtigste først

Den fremtidige produktretning er besluttet i:
- `[DENMARK_FIRST_PRODUCT_RESET.md](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/Tribunetour_docs/docs/DENMARK_FIRST_PRODUCT_RESET.md)`

iOS bliver eneste produktflade. Web-repoet er under migration et drifts- og overgangssystem, indtil nødvendige jobs er flyttet eller fjernet.

Tribunetour er ikke ét repo.

Tribunetour består lige nu af mindst to produktkritiske kodebaser, som ligger i samme arbejdsmappe:
- app-repoet i roden
- web-repoet i `[Website repo](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo)`

Det betyder:
- lokal “grøn status” i app-repoet siger intet om web-repoet
- en commit i ét repo løser ikke nødvendigvis noget i det andet
- en deploy til web er noget andet end en TestFlight-release
- en dataændring kan være rigtig ét sted og stadig være forkert i drift et andet sted

Det har været en reel kilde til fejl og forvirring.

## 2. Systemlandskab

### A. App-repo
Placering:
- `[Tribunetour app root](/Users/martintoudal/Documents/Tribunetour/Tribunetour)`

Ejer primært:
- iOS-appens UI og navigation
- appens lokale dataindlæsning
- appens rendering af stadions, kampe, plan og min tur
- app-specifik performance
- appens overgangslag og sync-klienter

Vigtige områder:
- `[AppState.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/AppState.swift)`
- `[ContentView.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/ContentView.swift)`
- `[CSVClubImporter.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/CSVClubImporter.swift)`
- `[FixturesCSVImporter.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/FixturesCSVImporter.swift)`
- `[RemoteFixturesProvider.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/RemoteFixturesProvider.swift)`
- `[stadiums.csv](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/stadiums.csv)`
- `[fixtures.csv](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/fixtures.csv)`

### B. Web-repo under udfasning som produkt
Placering:
- `[Website repo](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo)`

Ejer under migrationen primært:
- den eksisterende webflade på `tribunetour.dk`, indtil den udfases
- reference-data til web
- fixture-audits, daily fixture checks og mailnotifikationer
- scripts til import, generering og verifikation af ligadata
- Supabase-relateret drift på webfladen

Vigtige områder:
- `[README.md](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/README.md)`
- `[app](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/app)`
- `[data](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/data)`
- `[public/reference-data](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/public/reference-data)`
- `[scripts](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/scripts)`
- `[supabase](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/supabase)`

### C. Supabase, som bevares
Ejer primært:
- auth
- brugerdata på tværs af flader
- eksisterende adgangsrettigheder/premium under kontrolleret udfasning
- noter, billeder, reviews, visited, weekendplan hvor de er delt

Supabase er ikke et separat repo her, men et delt backend-system.

### D. Reference- og fixturedata
Data findes i praksis flere steder:
- appens CSV-filer
- webrepoets JSON-filer
- webrepoets league packs, auditfiler og scripts

Det er her en stor del af kompleksiteten bor lige nu.

## 3. Hvad der er source of truth lige nu

Vi skal være ærlige her: vi har ikke én samlet source of truth for hele produktet endnu.

Vi har en delt sandhed pr. område.

### UI
- Appens UI sandhed ligger i app-repoet
- Webens UI sandhed ligger i web-repoet

Konsekvens:
- “det ser rigtigt ud i appen” betyder ikke at web er korrekt
- og omvendt

### Brugerdata
- Supabase er source of truth for de delte brugerdataområder, hvor integrationen er indført

### Web-reference-data
- Web-repoets genererede datafiler og scripts er source of truth for webens fixtures og reference-data

Typisk:
- `[data/fixtures.json](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/data/fixtures.json)`
- `[public/reference-data/fixtures.remote.json](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/public/reference-data/fixtures.remote.json)`

### App-reference-data
- Appens CSV-filer er stadig source of truth for den lokale app-build

Typisk:
- `[stadiums.csv](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/stadiums.csv)`
- `[fixtures.csv](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/fixtures.csv)`

### Drift af fixture checks
- Web-repoets scripts og workflows er source of truth

Typisk:
- `[scripts/run-daily-fixture-check.py](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/scripts/run-daily-fixture-check.py)`
- `[scripts/run-fixture-audits.py](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/scripts/run-fixture-audits.py)`
- `[data/fixture-audits](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/data/fixture-audits)`

## 4. Hvor det går galt i dag

De vigtigste strukturelle problemer er:

### Problem 1: To repoer i samme arbejdsmappe giver falsk tryghed
Når vi står i én mappe, føles det som ét system.

Det er det ikke.

Det har skabt fejl som:
- ændringer lavet i forkert repo
- lokal oprydning kun i ét repo
- forkert forståelse af hvad der var “på plads lokalt”

### Problem 2: Data pipeline er ikke fuldt konsolideret
Vi har stadig:
- app-CSV-spor
- web-JSON-spor
- scripts, audits og league packs i web
- delvist fælles backend

Det giver for stor risiko for:
- forskellige svar i app og web
- forskellig timing på opdateringer
- uklart ejerskab ved fejl

### Problem 3: Dokumentationen beskriver delvist en ønsket fremtid som om den allerede er driftssandhed
Nogle dokumenter beskriver Tribunetour som mere samlet end den faktisk er.

Det er farligt, fordi det giver:
- dårligere beslutninger
- forkerte antagelser
- for lav friktion før vi ændrer noget i drift

### Problem 4: Manglende fast ændringsprotokol
Vi har for ofte arbejdet i denne rækkefølge:
- se fejl
- rette fejl
- opdage repo-grænser eller deploy-forhold bagefter

Vi skal i stedet arbejde:
- UX-afklaring
- arkitekturpåvirkning
- repo-afgrænsning
- udvikling
- dokumentation
- test
- deploy/release-verifikation

## 5. Driftsmodel vi skal arbejde efter fremover

For alle ændringer i dette projekt gælder nu denne minimumsprotokol:

### Trin 1: UX-afklaring
Vi afklarer:
- hvad brugeren oplever i dag
- hvad der konkret er forkert
- hvordan det skal opleves bagefter

### Trin 2: Arkitekturafklaring
Vi afklarer:
- hvilket system ejer problemet
- om det er app, web, backend, data eller drift
- om ændringen påvirker flere flader

### Trin 3: Product owner-afklaring
Vi afklarer:
- hvad der er i scope nu
- hvad der udskydes
- hvad der er acceptkriteriet

### Trin 4: Udvikling
Vi ændrer kun i det eller de systemer, som faktisk ejer problemet.

### Trin 5: Dokumentation
Vi opdaterer:
- backlog hvis arbejdet åbner eller lukker noget
- styringsdokument hvis ejerskab eller dataflow ændres

### Trin 6: Test
Vi tester det relevante sted:
- app-test for appfejl
- web-test for webfejl
- audit/daily-check for driftsfejl

For layoutkritiske ændringer i iOS gælder desuden:
- eksistens eller klikbarhed er ikke tilstrækkelig som UI-test
- centrale elementers geometri skal ligge inden for app-vinduets venstre og højre kant
- portrait skal som minimum testes ved kompakt, Pro og Pro Max-bredde
- den primære Pro-størrelse skal også kontrolleres visuelt
- faste skærmbredder undgås; layout bygges med systemets størrelsesforslag, adaptive rækker og `ViewThatFits`, hvor indhold kan kræve en kompakt variant

### Trin 7: Drift/leverance
Vi gør eksplicit klart:
- kræver det commit?
- kræver det push?
- kræver det deploy?
- kræver det ny app-build?
- kræver det ny TestFlight/App Store-release?

## 6. Konkret sandhed pr. ændringstype

### Hvis problemet er i app-UI
Start i:
- app-repoet

Typisk leverance:
- kodeændring
- lokal build
- evt. TestFlight-release

### Hvis problemet er i web-UI under migrationen
Start i:
- web-repoet

Web-UI får kun fejlrettelser, som er nødvendige frem til udfasningen. Nye produktfunktioner bygges ikke her.

Typisk leverance:
- kodeændring
- push
- deploy

### Hvis problemet er fixture-mail, audit eller daily check
Start i:
- web-repoet

Typisk leverance:
- script- eller dataændring
- push
- deploy eller workflow-kørsel

### Hvis problemet er brugerdata eller adgang
Start i:
- Supabase-kontrakt og den flade hvor symptomet vises

Typisk leverance:
- backend- eller query-ændring
- verifikation i både app og web hvis funktionen er delt

### Hvis problemet er forskel mellem app og web
Start i:
- dette dokument

Først afklarer vi:
- er forskellen bevidst?
- er forskellen teknisk arv?
- er forskellen et dataproblem?
- er forskellen et UI-problem?

## 7. Den vigtigste arkitektoniske retning herfra

Vi skal arbejde mod færre sandheder.

Det betyder ikke nødvendigvis ét repo med det samme.  
Men det betyder:

### Mål A
Én tydelig data-pipeline for reference-data og fixtures

### Mål B
Én tydelig definition af hvilke felter der ejes af appen, webben og backend

### Mål C
Ens mental model mellem app og web

Du har allerede sagt det klart:
- layout må gerne tilpasses
- men design og funktionalitet skal være så ens som muligt

Det skal vi nu behandle som et produktprincip, ikke bare en præference.

### Mål D
Ét sted hvor driftsstatus og kendte problemer samles

Backloggen er ikke nok alene.  
Vi har også brug for et operationsblik.

## 8. Beslutninger vi bør lægge fast nu

### Beslutning 1
`CURRENT_STATE.md` er ikke tilstrækkeligt som driftssandhed alene.

Det dokument er nyttigt, men det beskriver løsningen mere optimistisk og mere konsolideret end den faktisk er i drift.

### Beslutning 2
Dette dokument er fremover den praktiske reference for:
- repo-afgrænsning
- source of truth
- deploy/release-forståelse
- ændringsprotokol

### Beslutning 3
Når vi siger “på plads”, skal det altid betyde:
- hvilket repo
- hvilken branch
- hvilken driftsoverflade
- om det er pushed
- om det er deployed
- om det er ude i app-build

## 9. Næste naturlige arkitekturspor

Den rigtige næste strukturforbedring er efter min vurdering:

1. lave ét simpelt systemkort for app, web, Supabase og fixture-pipeline
2. indføre en fast ændringsskabelon i backloggen
3. reducere data-duplikation mellem app og web
4. beslutte om reference-data på sigt skal genereres ét sted og konsumeres begge steder

## 10. Kort konklusion

Din bekymring er berettiget.

Problemet er ikke bare enkelte fejl.  
Problemet er, at arkitektur, drift og arbejdsproces ikke har været stram nok koblet sammen.

Det vi gør nu er derfor:
- vi stopper med at kalde dokumentation for overblik, hvis den ikke hjælper i drift
- vi gør repo-grænser og source-of-truth eksplicitte
- vi arbejder fremover med en fast proces før hver større ændring

Det er sådan vi får Tribunetour tilbage til at føles mere robust, mere forudsigelig og mere skalerbar.
