# Integration Backlog

## Formål
Dette dokument er den fulde backlog for arbejdet med at gøre Tribunetour til ét samlet produkt på tværs af:
- iOS-app
- web
- auth
- reference-data
- brugerdata

Målet er ikke bare teknisk integration.

Målet er:
- ét produkt
- to flader
- samme identitet
- samme kernebegreber
- samme datamæssige sandhed, hvor det giver mening

---

## Arbejdsprincip

Backloggen er opdelt i:
- `Nu` = bør lukkes først
- `Næste` = vigtig bagefter
- `Senere` = relevant, men ikke blokkerende for at samle produktet

Hver opgave har:
- et ID
- en kort beskrivelse
- hvorfor den findes
- et ønsket resultat

---

## Statusmål

Når integrationsarbejdet er færdigt, skal dette være sandt:
- app og web bruger samme auth-retning
- app og web bruger samme reference-data-pipeline
- `visited` har én fælles model og én tydelig source of truth
- brugeren forstår ikke længere app og web som to forskellige systemer
- migrationslogik er reduceret til et minimum eller fjernet

---

## Aktuel arbejdsplan

Dette er den mest praktiske prioritering lige nu, hvis målet er at få Tribunetour fra “koblet sammen i overgang” til “reelt ét produkt”.

Backloggen længere nede er stadig den fulde arbejdsflade.
Denne sektion er den operative læserækkefølge.

### Nu

#### NOW-00 Luk de sidste dataspot før integreret release
**Status:** Nu

**Mål**
- gøre Tribunetour til ét produkt hele vejen rundt før næste release

**Leverance**
- beslutning og implementering for `photos`
- beslutning og implementering for `weekend plan`
- beslutning om progression/achievements på web

#### NOW-01 Lås reference-data som ét flow
**Status:** Nu

**Mål**
- undgå nyt mismatch mellem app og web
- gøre reference-data til et kontrolleret driftsflow frem for manuel synkronisering

**Leverance**
- én canonical source for stadions, klubber og fixtures
- ét fælles output-format eller én genereret kontrakt
- tydelig fallback-regel for klienterne

#### NOW-02 Lav ét reference-data-lag på web
**Status:** Nu

**Mål**
- fjerne direkte dataopslag spredt i web-fladen
- gøre det muligt at skifte datakilde uden at rive UI’et op

**Leverance**
- ét `referenceData`-modul
- stadion-, kamp- og detaljesider læser gennem samme indgang

#### NOW-03 Beslut steady-state for `visited`
**Status:** Nu

**Mål**
- gøre det entydigt hvad der er sandheden efter bootstrap
- undgå at migrationsarkitekturen bliver permanent drift

**Leverance**
- skrevet beslutning om hvornår shared backend er autoritativ
- skrevet beslutning om CloudKits rolle bagefter

#### NOW-04 Gør bootstrap og sync releaseklare
**Status:** Nu

**Mål**
- gøre første login trygt og forståeligt
- gøre sync-fejl produktforståelige i stedet for tekniske

**Leverance**
- stram bootstrap-copy
- tydelige fejltilstande for login, session og sync
- klar brugerhandling når noget fejler

#### NOW-05 Få dokumentation og driftshistorie til at matche virkeligheden
**Status:** Nu

**Mål**
- undgå at README’er, kode og produktretning fortæller forskellige historier

**Leverance**
- opdaterede README’er
- docs der matcher auth-model, visited-model og web/app-relationen

### Næste

#### NEXT-01 Reducér overgangslag i appen
**Status:** Næste

**Mål**
- gøre sync-arkitekturen enklere at forstå og vedligeholde

**Leverance**
- færre runtime-modes
- mindre intern migrationslogik i normal drift

#### NEXT-02 Beslut shared vs. app-only data
**Status:** Næste

**Mål**
- gøre det tydeligt hvilke dataområder der faktisk er fælles produktspor

**Leverance**
- klar opdeling for:
  - noter
  - billeder
  - plan/weekend-plan
  - progression/achievements på web

#### NEXT-03 Lav tværflade test- og releasecheck
**Status:** Lukket

**Mål**
- kunne kalde integrationen en reel leverance og ikke bare en løbende retning

**Leverance**
- checkliste for build, login, bootstrap, visited og reference-data
- kort go/no-go før næste integrationsegnede release

**Resultat**
- checkliste findes
- `visited` er verificeret manuelt begge veje mellem app og web
- kendt restpunkt er realtime/subscription-niveau, ikke grundlæggende datakonsistens

### Senere

#### LATER-01 Beslut webens mål-paritet
**Status:** Senere

**Mål**
- definere hvor langt web faktisk skal gå som produktflade

**Leverance**
- tydeligt scope for `Stadions`, `Kampe` og `Min tur`

#### LATER-02 Udvid shared brugerdata ud over `visited`
**Status:** Senere

**Mål**
- tage næste datatyper bevidst og i rigtig rækkefølge

**Leverance**
- prioriteret plan for noter, reviews, billeder og planer

---

## Fase 1: Fundament

### INT-01 Saml reference-data i én fælles pipeline
**Status:** Nu

**Problem**
App og web kan igen drive fra hinanden, hvis kampprogram eller stadions kun opdateres ét sted.

**Arbejdet**
- definér én fælles reference-data-kilde
- definér ét fælles output-format for web og app
- lad web læse via et fælles loader-lag i stedet for direkte lokale JSON-filer
- behold lokal fallback, men gør den sekundær

**Resultat**
- app og web viser samme stadions og samme kampe uden manuelle dobbeltopdateringer

### INT-02 Lav et lille reference-data-lag på web
**Status:** Nu

**Problem**
Web læser i dag reference-data direkte i flere sider og komponenter.

**Arbejdet**
- opret et samlet `referenceData`-modul i web
- flyt fixtures/stadiums-indlæsning bag det modul
- lad kamp- og stadionvisninger bruge samme indgang

**Resultat**
- web kan skifte datakilde uden at rive UI-komponenter op

### INT-03 Gør reference-data validering til fast del af flowet
**Status:** Nu

**Problem**
Reference-data kan stadig bryde relationer uden at det opdages tidligt nok.

**Arbejdet**
- fastlæg validator-regler for stadium IDs, fixture IDs og relationer
- sørg for at både web og app-data kan valideres mod samme kontrakt
- beslut hvornår validering skal køres: lokalt, før deploy, eller begge

**Resultat**
- fremtidige fixture-opdateringer bliver rutine frem for risikozone

### INT-04 Dokumentér den endelige reference-data-kontrakt
**Status:** Nu

**Problem**
Kontrakten er delvist beskrevet, men bør være operationel og ikke kun principiel.

**Arbejdet**
- præcisér canonical source
- præcisér format
- præcisér fallback-regler
- præcisér opdateringsflow

**Resultat**
- ingen tvivl om hvor reference-data kommer fra

---

## Fase 2: Fælles visited-model

### INT-10 Lås den fælles visited-model som produktstandard
**Status:** Nu

**Problem**
Shared `visited` findes, men opleves stadig som migrationsspor.

**Arbejdet**
- bekræft at `visited`-modellen i docs er den reelle standard
- bekræft felter, semantik og konfliktregler
- fjern tvetydighed mellem legacy-model og target-model

**Resultat**
- app og web taler om samme visited-record

### INT-11 Beslut endelig source of truth efter bootstrap
**Status:** Lukket

**Problem**
Appen er stadig primær i overgangsfasen, men steady-state er ikke helt låst produktmæssigt.

**Arbejdet**
- beslut hvornår shared backend er autoritativ
- beslut hvad CloudKit skal være efter migration
- dokumentér steady-state tydeligt

**Resultat**
- teamet ved hvad “færdig” betyder for `visited`

### INT-12 Stabiliser tværflade-sync for `visited`
**Status:** Lukket

**Problem**
`visited` blev først synkroniseret, men kunne vippe mellem app og web, fordi hybrid-laget stadig blandede legacy-state ind.

**Arbejdet**
- appen refresher shared `visited` ved login og aktivering
- web refetche’r `visited` ved fokus og visibility
- shared backend er gjort autoritativ for `visited` i steady-state
- passiv remote refresh pusher ikke længere automatisk data tilbage

**Resultat**
- `visited` forbliver stabil mellem app og web efter ændringer
- shared backend fungerer nu som reel fælles sandhed for `visited`

### INT-12 Gør bootstrap-flowet produktklart
**Status:** Nu

**Problem**
Bootstrap findes, men skal opleves som forståeligt og sikkert for rigtige brugere.

**Arbejdet**
- gennemgå first-login-flow i appen
- stram brugerbesked og bekræftelsesflow
- tydeliggør hvad der sker første gang en bruger forbinder app og web

**Resultat**
- første login føles kontrolleret, ikke eksperimentelt

### INT-13 Gør sync-fejl brugerforståelige
**Status:** Nu

**Problem**
Tekniske backend-fejl kan stadig lække direkte til UI.

**Arbejdet**
- oversæt auth- og sync-fejl til klare produktbeskeder
- adskil session-fejl, netværksfejl og serverfejl
- gør “log ind igen” til en tydelig handling når relevant

**Resultat**
- sync føles robust, også når noget fejler

### INT-14 Lav en egentlig steady-state testplan for visited
**Status:** Nu

**Problem**
Der findes hybrid-testplan, men der mangler en plan for den endelige model.

**Arbejdet**
- beskriv tests for login, bootstrap, markér besøgt, markér ubesøgt
- test på tværs af app og web
- definér go/no-go før bredere brug

**Resultat**
- visited-sync kan betragtes som releasebar funktionalitet

---

## Fase 3: Oprydning i overgangslag

### INT-20 Reducér runtime-modes i appen
**Status:** Lukket

**Problem**
`cloudKitPrimary`, `sharedPrepared` og `hybridPrepared` er nyttige internt, men ikke ønskelig permanent produkttilstand.

**Arbejdet**
- vurder hvilke modes der stadig er nødvendige
- fjern eller skjul modes der kun er migrationsværktøj
- bevar kun det der giver reel driftssikkerhed

**Resultat**
- appens sync-arkitektur bliver enklere og lettere at forstå

### INT-24 Udfas `CloudKit (legacy)` som brugerrelevant mode
**Status:** Senere

**Problem**
Selv efter runtime-oprydningen findes `CloudKit (legacy)` stadig som bevidst fallback og intern valgmulighed, hvilket holder en gammel produktmodel synlig længere end ønskeligt.

**Arbejdet**
- beslut hvornår legacy-mode kan fjernes helt fra produktet
- afklar om CloudKit kun skal leve som intern nødseam eller udfases helt
- fjern brugerrettede spor når steady-state har været stabil i drift

**Resultat**
- shared visited står tilbage som én tydelig produktmodel

### INT-21 Beslut CloudKits endelige rolle
**Status:** Næste

**Problem**
CloudKit lever stadig i arkitekturen, men det er uklart om det er permanent, sekundært eller kun legacy.

**Arbejdet**
- beslut om CloudKit skal udfases, spejles eller beholdes til bestemte datatyper
- dokumentér beslutningen

**Resultat**
- færre skjulte arkitekturforbehold

### INT-22 Ryd migrationscopy op i app og web
**Status:** Næste

**Problem**
Produktet bør ikke permanent kommunikere som om det er midt i migration.

**Arbejdet**
- identificér overgangsbeskeder
- fjern eller omskriv dem når steady-state er klar
- behold kun nødvendig brugerhjælp

**Resultat**
- produktet føles samlet og modent

### INT-23 Stram debug- og interne værktøjsseams
**Status:** Næste

**Problem**
Interne testseams må ikke blive forvekslet med permanent brugeradfærd.

**Arbejdet**
- gennemgå interne værktøjer og runtime-flags
- sørg for at de er tydeligt interne
- fjern legacy-testsømmme der ikke længere er nødvendige

**Resultat**
- færre fejlkilder i næste releasefase

---

## Fase 4: Web som reel produktflade

### INT-30 Beslut webs mål-paritet med appen
**Status:** Næste

**Problem**
Appen har mere funktionalitet end web, men det er ikke besluttet præcist hvor web skal ende.

**Arbejdet**
- lav et klart scope for web
- beslut hvad web skal have paritet på
- beslut hvad der forbliver app-first

**Resultat**
- web udvikles mod et klart mål, ikke bare “mere”

### INT-31 Giv web samme kerneinformationsarkitektur som appen
**Status:** Næste

**Problem**
Produktet skal opleves som ét, ikke som to forskellige navigationer og sprogverdener.

**Arbejdet**
- gennemgå `Stadions`, `Kampe`, `Min tur`
- sikre ens labels, states og forventninger
- ensret centrale tom-, loading- og fejlsituationer

**Resultat**
- brugeren kan skifte flade uden at “skifte produkt”

### INT-32 Gør webens `Min tur` tydeligt kompatibel med appens model
**Status:** Næste

**Problem**
Web har en enklere udgave, mens appen har den modne oplevelse.

**Arbejdet**
- afklar hvilke `Min tur`-elementer der skal deles
- brug samme visited-logik og samme progressionstænkning
- hold forskelle bevidste og dokumenterede

**Resultat**
- `Min tur` bliver samme produktidé på begge flader

---

## Fase 5: Shared brugerdata ud over visited

### INT-40 Beslut rækkefølge for næste shared datatyper
**Status:** Lukket

**Problem**
Appen har noter, reviews, billeder og planer, men alt bør ikke gøres shared på én gang.

**Arbejdet**
- prioriter næste dataområde efter `visited`
- beslut hvad der giver mest værdi med mindst risiko

**Resultat**
- en realistisk konvergensplan i stedet for en stor omskrivning

### INT-41 Noter
**Status:** Bygget i første version

**Arbejdet**
- beslut om noter skal være shared
- hvis ja: definér kontrakt, conflict policy og UI-forventning

**Aktuel beslutning**
- `notes` er valgt som næste shared datamodel efter `visited`
- første delte version er nu bygget og verificeret begge veje
- næste arbejde er derfor ikke at vælge område igen, men at modne notes yderligere eller vælge næste datamodel

### INT-42 Reviews
**Status:** Næste

**Arbejdet**
- beslut om reviews skal være shared eller app-first
- afklar struktur, ejerskab og visningsbehov på web

**Aktuel beslutning**
- `reviews` er nu det næste bevidste shared dataområde efter `notes`
- arbejdet skal holdes smallere end den nuværende appmodel, så vi ikke blander billeder, kategori-noter og summary-flow sammen for tidligt

### INT-43 Fotos
**Status:** Senere

**Arbejdet**
- beslut om fotos skal være shared
- afklar storage, sync-retning og produktværdi på web

### INT-44 Plan / weekend-plan
**Status:** Senere

**Arbejdet**
- beslut om plan skal være personlig shared funktion
- afklar om web skal kunne læse, skrive eller kun vise senere

---

## Fase 6: Konsolidering og release

### INT-50 Saml integrationsgrenen i en ren releasebar tilstand
**Status:** Næste

**Problem**
Der ligger mange lokale og overlappende ændringer, som gør det svært at se hvad der faktisk er “den færdige løsning”.

**Arbejdet**
- ryd relaterede filer op
- saml docs med kodevirkeligheden
- fjern døde spor

**Resultat**
- repoet afspejler den reelle arkitektur

### INT-51 Lav en integrations-release-checkliste
**Status:** Næste

**Arbejdet**
- build-check
- login-check
- bootstrap-check
- visited-check på tværs
- reference-data-check
- produktcopy-check

**Resultat**
- integrationen kan lukkes som en reel leverance

### INT-52 Definér “integration færdig”
**Status:** Næste

**Problem**
Ellers risikerer integrationen at fortsætte som et evigt mellemstadie.

**Arbejdet**
- skriv en kort Definition of Done
- beslut hvilke kompromiser der er acceptable
- beslut hvad der ikke behøver være med i første færdige version

**Resultat**
- arbejdet kan afsluttes med en tydelig beslutning

---

## Prioriteret rækkefølge

Hvis vi skal tage det bid for bid, er dette den anbefalede rækkefølge:

1. `INT-01` Saml reference-data i én fælles pipeline
2. `INT-02` Lav et lille reference-data-lag på web
3. `INT-03` Gør reference-data validering fast
4. `INT-10` Lås den fælles visited-model
5. `INT-11` Beslut endelig source of truth efter bootstrap
6. `INT-12` Gør bootstrap-flowet produktklart
7. `INT-13` Gør sync-fejl brugerforståelige
8. `INT-20` Reducér runtime-modes i appen
9. `INT-21` Beslut CloudKits endelige rolle
10. `INT-30` Beslut webs mål-paritet med appen
11. `INT-50` Saml integrationsgrenen i ren releasebar tilstand
12. `INT-52` Definér “integration færdig”

---

## Minimum færdigpakke

Hvis målet er at få integrationen “færdig nok” uden at åbne alt på én gang, er minimumspakken:
- fælles auth
- fælles `visited`
- fælles reference-data-pipeline
- tydelig source of truth
- oprydning i migrationslag

Det er den mindste version, hvor Tribunetour reelt kan kaldes:

`ét produkt med to flader`

---

## Sprint 1

Dette er den første konkrete arbejdspakke, jeg ville vælge nu.

Målet med Sprint 1 er:
- at fjerne risikoen for nyt app/web-mismatch
- at gøre `visited`-sporet mere produktklart
- at skabe et klart grundlag for næste integrationssprint

### Sprint 1 scope

#### S1-01 Læg webens reference-data bag ét samlet loader-lag
Bygger på:
- `INT-01`
- `INT-02`

Leverance:
- ét `referenceData`-modul i web
- kamp- og stadionsider bruger samme loader

Hvorfor nu:
- det er den vigtigste tekniske kilde til nyt mismatch

#### S1-02 Definér canonical source for reference-data
Bygger på:
- `INT-01`
- `INT-04`

Leverance:
- kort beslutning om hvad der er sand kilde
- tydelig fallback-regel
- docs opdateret til operationel retning

Hvorfor nu:
- ellers bygger vi loader-lag uden fast kildehierarki

#### S1-03 Gør reference-data-validering til fast check
Bygger på:
- `INT-03`

Leverance:
- validator-regler fastlagt
- praktisk checkflow beskrevet

Hvorfor nu:
- reference-data bliver først reelt sikkert, når validering er rutine

#### S1-04 Gør sync-fejl mere menneskelige i appen
Bygger på:
- `INT-13`

Leverance:
- rå backend-fejl skjules
- brugeren får handlinger som “log ind igen” når det er relevant

Hvorfor nu:
- funktionaliteten virker allerede; nu skal den også føles stabil

#### S1-05 Stram bootstrap-copy og førstegangsflow i appen
Bygger på:
- `INT-12`

Leverance:
- tydelig besked om hvad første login gør
- mindre migrationsforvirring

Hvorfor nu:
- bootstrap er central for tillid til den fælles model

#### S1-06 Beslut steady-state for `visited`
Bygger på:
- `INT-10`
- `INT-11`

Leverance:
- kort arkitekturbeslutning om hvornår shared backend er autoritativ
- kort beslutning om CloudKits rolle efter bootstrap

Hvorfor nu:
- ellers bliver overgangslaget ved med at leve for længe

### Sprint 1 DoD

Sprint 1 er færdig når:
- web ikke længere læser fixtures flere steder direkte fra lokale filer
- reference-data har ét dokumenteret kildehierarki
- validator-regler er besluttet og kan bruges i praksis
- appens sync-fejl er produktforståelige
- bootstrap-flowet er tydeligt for brugeren
- teamet har en skrevet beslutning om `visited` steady-state

### Sprint 1 næste konsekvens

Hvis Sprint 1 lukkes, bliver Sprint 2 meget enklere.

Så vil næste sprint naturligt kunne fokusere på:
- reduktion af runtime-modes
- CloudKit-oprydning
- webens mål-paritet
- integrations-release og Definition of Done

---

## Sprint 2

Dette er den aktuelle næste arbejdspakke efter, at shared `visited` og remote reference-data nu virker i praksis.

Målet med Sprint 2 er:
- at gøre integrationsfundamentet releaseklart som fast rutine
- at færdiggøre reference-data-flowet som driftsspor
- at rydde mere overgangslag ud, nu hvor steady-state er stabil
- at vælge næste shared datamodel bevidst i stedet for at sprede arbejdet

### Sprint 2 scope

#### S2-01 Kør og fastlås en kort integrations sanity-check
Bygger på:
- `NEXT-03`
- `INT-14`

Leverance:
- en kort gentagelig testrutine for gæst, login, bootstrap og `visited` begge veje
- tydelig markering af hvad der er grønt nu, og hvad der stadig kun er kendt begrænsning

Hvorfor nu:
- vi har stabiliseret meget hurtigt, og nu skal det kunne gentages uden at opfinde testen hver gang

#### S2-02 Færdiggør reference-data-pipelinen som ét driftsspor
Bygger på:
- `INT-01`
- `INT-03`
- `INT-04`

Leverance:
- klart update-flow fra canonical source til web-artefakter og app-feed
- kort beskrivelse af hvem der opdaterer data, og hvordan det verificeres

Hvorfor nu:
- reference-data er nu den største tilbageværende strukturelle risiko for nyt mismatch

#### S2-03 Ryd mere migrationslag ud af appen
Bygger på:
- `INT-21`
- `INT-22`
- `INT-23`

Leverance:
- identificeret liste over resterende legacy-copy, debug-seams og overgangsantagelser
- første sikre oprydningsrunde i normal brugerflade

Hvorfor nu:
- `visited` er stabil nok til, at produktet bør føles mindre som migration og mere som drift

#### S2-04 Beslut næste shared dataområde
Bygger på:
- `NEXT-02`
- `INT-40`

Leverance:
- én skrevet beslutning om næste datamodel efter `visited`
- fravalg for de områder, der ikke tages nu

Hvorfor nu:
- ellers risikerer vi at sprede indsatsen over noter, reviews, fotos og plan på samme tid

#### S2-05 Stram release-checklisten til egentlig drift
Bygger på:
- `INT-51`
- `INT-52`

Leverance:
- opdateret go/no-go med den nuværende integrationsvirkelighed
- klar skelnen mellem blockers og kendte ikke-realtime-begrænsninger

Hvorfor nu:
- næste release-vurdering skal bygge på det, vi faktisk har verificeret, ikke på den gamle migrationsforståelse

Status:
- lukket
- release-checklisten skelner nu tydeligt mellem `Go med kendt begrænsning` og reelle blockers

### Sprint 2 DoD

Sprint 2 er færdig når:
- integrations sanity-check kan køres hurtigt og gentages uden tvivl
- reference-data update-flowet er beskrevet som én driftspipeline
- mindst én runde migrationscopy og legacy-seams er ryddet væk
- næste shared datamodel er valgt bevidst
- release-checklisten afspejler den faktiske steady-state for `visited`

### Sprint 2 næste konsekvens

Hvis Sprint 2 lukkes, bliver næste sprint langt mere produktorienteret.

Så vil næste sprint naturligt kunne fokusere på:
- næste shared datamodel
- webens mål-paritet
- evt. realtime/subscription-sync som forbedring og ikke som redning

Aktuel vurdering:
- Sprint 2 er nu lukket som dokumentations- og stabiliseringssprint
- næste naturlige produktspor er `INT-41 Noter`

---

## Sprint 3

Dette er den næste konkrete arbejdspakke, hvor Tribunetour går fra delt `visited` til første richer shared brugerdata.

Målet med Sprint 3 er:
- at gøre `notes` til den næste bevidste shared datamodel
- at holde scope smalt, så vi ikke blander reviews, fotos og plan ind samtidig
- at definere kontrakt og forventning før bred UI-udbygning

### Sprint 3 scope

#### S3-01 Definér shared notes-kontrakten
Bygger på:
- `INT-41`

Leverance:
- skrevet kontrakt for `notes`
- beslutning om tom note, opdateringstidspunkt og conflict-retning
- tydelig regel for hvordan note knytter sig til `clubId`

Hvorfor nu:
- uden kontrakt risikerer vi at bygge app og web mod hver sin note-model

#### S3-02 Lav en app-boundary for notes
Bygger på:
- `INT-41`

Leverance:
- én tydelig seam mellem lokal/app-only note-model og kommende shared note-model
- ingen skjult spredning af note-logik i mange views

Hvorfor nu:
- notes skal kunne deles uden at gøre `VisitedStore` endnu mere mudret

#### S3-03 Etabler første shared backend-retning for notes
Bygger på:
- `S3-01`
- `S3-02`

Leverance:
- første repository/backend-kontrakt for notes
- klar læse-/skriveretning for samme bruger på app og web

Hvorfor nu:
- vi skal bevise modellen end-to-end tidligt, ikke kun dokumentere den

#### S3-04 Vis notes ét sted på web og ét sted i appen
Bygger på:
- `S3-03`

Leverance:
- ét enkelt, tydeligt note-entrypoint i web
- ét tilsvarende note-entrypoint i appen
- ingen bred paritet endnu, kun et bevidst første flow

Hvorfor nu:
- det er nok til at validere brugeroplevelsen uden at åbne hele UI-fladen på én gang

#### S3-05 Tilføj en notes sanity-test
Bygger på:
- `S3-04`

Leverance:
- kort testflow for note opret/redigér på tværs af app og web
- tydelig placering af fejl som `notes`, ikke generisk sync

Hvorfor nu:
- `notes` skal ikke gentage det tidlige `visited`-forløb med uklar ansvarslinje

Status:
- lukket i første version via notes sanity-rutine i `RELEASE.md`

### Sprint 3 DoD

Sprint 3 er færdig når:
- shared notes-kontrakten er skrevet og godkendt
- app og web kan læse/skrive samme note-model i mindst ét bevidst flow
- notes har en lille, gentagelig tværflade-test
- reviews, fotos og plan stadig bevidst er ude af scope

Aktuel status:
- `S3-01` til `S3-05` er lukket
- notes virker nu begge veje mellem app og web
- næste naturlige spor efter Sprint 3 er enten modning af notes eller valg af næste shared datamodel

### Sprint 3 anbefalet rækkefølge

1. `S3-01` kontrakt
2. `S3-02` app-boundary
3. `S3-03` backend/repository
4. `S3-04` første UI-flow
5. `S3-05` sanity-test

---

## Sprint 4

Dette er den næste konkrete arbejdspakke, hvor Tribunetour går fra delt `notes` til første shared `reviews`-model.

Målet med Sprint 4 er:
- at gøre `reviews` til den næste bevidste shared datamodel
- at bruge samme reviewmodel i app og web
- at holde fotos udenfor, så vi ikke forsøger at dele hele review- og fotooplevelsen på én gang

### Sprint 4 scope

#### S4-01 Definér shared reviews-kontrakten
Bygger på:
- `INT-42`

Leverance:
- skrevet kontrakt for `reviews`
- låst at shared `review` følger appens eksisterende `StadiumReview`
- tydelig konfliktretning og relation til `clubId`

Hvorfor nu:
- reviews er mere komplekse end `notes`, så vi skal være endnu skarpere på modellen før implementering
- en separat webmodel vil skabe unødig mapping og ekstra fejlflader

#### S4-02 Lav en app-boundary for reviews
Bygger på:
- `INT-42`

Leverance:
- én tydelig seam mellem lokal review-lagring og shared review-sync
- mindre direkte kobling mellem UI og `VisitedStore`

Hvorfor nu:
- appens review-model er allerede rig, og vi skal beskytte sync-laget uden at opfinde en anden model

#### S4-03 Etabler første shared backend-retning for reviews
Bygger på:
- `S4-01`
- `S4-02`

Leverance:
- første repository/backend-kontrakt for reviews
- klar read/write-retning for samme bruger på app og web

Hvorfor nu:
- vi skal bevise drift og ikke kun datadesign

#### S4-04 Vis reviews ét sted på web og ét sted i appen
Bygger på:
- `S4-03`

Leverance:
- ét enkelt review-entrypoint på web
- ét tilsvarende review-entrypoint i appen
- samme reviewfelter bag begge flows
- ingen bred paritet endnu

Hvorfor nu:
- det giver nok bruger- og produktvalidering uden at åbne alle reviewflader samtidig

#### S4-05 Tilføj en review sanity-test
Bygger på:
- `S4-04`

Leverance:
- kort testflow for review opret/redigér på tværs af app og web
- tydelig fejlplacering som `review auth`, `review read`, `review write` eller `review merge`

Hvorfor nu:
- reviews skal følge samme driftsdisciplin som `visited` og `notes`

### Sprint 4 DoD

Sprint 4 er færdig når:
- shared review-kontrakten er skrevet og godkendt
- app og web kan læse/skrive samme review-model i mindst ét bevidst flow
- reviews har en lille, gentagelig tværflade-test
- fotos og weekend-plan stadig bevidst er ude af scope

### Sprint 4 anbefalet rækkefølge

1. `S4-01` kontrakt
2. `S4-02` app-boundary
3. `S4-03` backend/repository
4. `S4-04` første UI-flow
5. `S4-05` sanity-test

---

## Konkrete tickets

Denne sektion omsætter backloggen til konkrete arbejdspakker med:
- formål
- primære kodeområder
- afhængigheder
- anbefalet rækkefølge

Den er tænkt som broen mellem strategi og faktisk implementering.

### T-01 Reference-data source of truth
**Prioritet:** Høj
**Bygger på:** `NOW-01`

**Formål**
- beslutte én canonical source for stadions, klubber og fixtures
- beslutte hvordan app og web får samme version af data

**Primære områder**
- `Tribunetour/Tribunetour_docs/docs/REFERENCE_DATA_CONTRACT.md`
- `Tribunetour/Tribunetour_docs/docs/INTEGRATION_STATUS.md`
- `Tribunetour/Tribunetour_docs/docs/ONE_PRODUCT.md`

**Leverance**
- kort beslutning om sand kilde
- kort beslutning om fallback
- kort beslutning om versionsstyring

### T-02 Web referenceData-modul
**Prioritet:** Høj
**Bygger på:** `NOW-01`, `NOW-02`

**Formål**
- samle webens dataadgang i ét lille lag
- fjerne direkte læsning af lokale filer og datakald fra UI-komponenter

**Primære områder**
- `Website repo/app/(site)/_components/StadiumList.tsx`
- `Website repo/app/(site)/_components/MatchesList.tsx`
- `Website repo/app/my/page.tsx`
- `Website repo/app/stadiums/[id]/page.tsx`
- `Website repo/app/matches/[id]/page.tsx`
- ny fil, fx `Website repo/app/(site)/_lib/referenceData.ts`

**Leverance**
- ét modul med `getStadiums`, `getFixtures`, `getStadiumById`, `getFixtureById`
- ovenstående sider læser via modulet

### T-03 Reference-data validation flow
**Prioritet:** Høj
**Bygger på:** `NOW-01`, `NOW-02`

**Formål**
- gøre datakonsistens til en fast kontrol

**Primære områder**
- `Website repo/scripts/validate-reference-data.mjs`
- `Website repo/package.json`
- `Tribunetour/Tribunetour_docs/docs/REFERENCE_DATA_CONTRACT.md`

**Leverance**
- validator-regler for ID’er og relationer
- beskrivelse af hvornår checket skal køres
- fast script som del af flowet

### T-04 Shared visited steady-state decision
**Prioritet:** Høj
**Bygger på:** `NOW-03`

**Formål**
- låse den endelige retning for `visited`

**Primære områder**
- `Tribunetour/Tribunetour_docs/docs/AUTH_AND_DATA_OWNERSHIP.md`
- `Tribunetour/Tribunetour_docs/docs/VISITED_MIGRATION_PLAN.md`
- `Tribunetour/Tribunetour_docs/docs/VISITED_BACKEND_CONTRACT.md`
- `Tribunetour/Tribunetour_docs/docs/INTEGRATION_STATUS.md`

**Leverance**
- én skrevet beslutning om hvornår shared backend er autoritativ
- én skrevet beslutning om hvad CloudKit gør bagefter
- tydelig konfliktretning i steady-state

### T-05 App bootstrap UX
**Prioritet:** Høj
**Bygger på:** `NOW-03`, `NOW-04`, `T-04`

**Formål**
- gøre første login og bootstrap sikkert og forståeligt

**Primære områder**
- `Tribunetour/StatsView.swift`
- `Tribunetour/AppState.swift`
- `Tribunetour/AppVisitedBootstrapCoordinator.swift`

**Leverance**
- stram tekst og tydelig konsekvens ved første login
- mindre migrationspræg i succes- og fejlbeskeder
- tydelig handling hvis bootstrap fejler

### T-06 App sync error handling
**Prioritet:** Høj
**Bygger på:** `NOW-04`

**Formål**
- oversætte tekniske fejl til produktforståelige beskeder

**Primære områder**
- `Tribunetour/StatsView.swift`
- `SharedVisitedSyncBackend.swift`
- `AppAuthClient.swift`
- `Tribunetour/VisitedStore.swift`

**Leverance**
- klar forskel på auth-fejl, session-fejl, netværksfejl og serverfejl
- tydelig “log ind igen”-handling når relevant

### T-07 Docs and README alignment
**Prioritet:** Høj
**Bygger på:** `NOW-05`

**Formål**
- få dokumentation og onboarding til at matche den faktiske løsning

**Primære områder**
- `Website repo/README.md`
- `Tribunetour/Tribunetour_docs/README.md`
- `Tribunetour/Tribunetour_docs/docs/INTEGRATION_STATUS.md`
- `Tribunetour/Tribunetour_docs/docs/RELEASE.md`

**Leverance**
- web README matcher faktisk auth- og visited-model
- app README matcher faktisk integrationsretning
- release-noter beskriver nuværende produktarkitektur korrekt

### T-08 Reduce runtime modes
**Status:** Lukket
**Prioritet:** Mellem
**Bygger på:** `NEXT-01`, `T-04`

**Formål**
- rydde overgangslag ud af normal drift

**Primære områder**
- `Tribunetour/AppVisitedSyncConfiguration.swift`
- `Tribunetour/AppVisitedSyncRuntimeFlags.swift`
- `Tribunetour/AppState.swift`
- `HybridVisitedSyncBackend.swift`

**Leverance**
- færre brugerrelevante modes
- tydeligere standardmode for appen

**Lukket med**
- `sharedPrepared` fjernet som reel mode med bagudkompatibel mapping
- runtime-promovering samlet i `AppVisitedSyncRuntimeFlags`
- gamle Xcode search paths og build-warnings ryddet op
- iOS-build verificeret med `BUILD SUCCEEDED`

### T-11 Remove CloudKit legacy mode from product surface
**Status:** Senere
**Prioritet:** Mellem
**Bygger på:** `INT-21`, `INT-24`

**Formål**
- afslutte den produktmæssige forenkling efter at overgangslaget er stabiliseret

**Primære områder**
- `Tribunetour/AppVisitedSyncConfiguration.swift`
- `Tribunetour/InternalToolsView.swift`
- `Tribunetour/StatsView.swift`
- `Tribunetour/Tribunetour_docs/docs/AUTH_AND_DATA_OWNERSHIP.md`

**Leverance**
- `CloudKit (legacy)` er ikke længere en brugerrelevant mode
- shared visited fremstår som eneste normale model

### T-09 Shared vs app-only data matrix
**Status:** Lukket
**Prioritet:** Mellem
**Bygger på:** `NEXT-02`

**Formål**
- gøre produktscope og datagrænser konkrete

**Primære områder**
- `Tribunetour/VisitedStore.swift`
- `Tribunetour/WeekendPlanStore.swift`
- `Tribunetour/Tribunetour_docs/docs/AUTH_AND_DATA_OWNERSHIP.md`
- `Tribunetour/Tribunetour_docs/docs/ONE_PRODUCT.md`

**Leverance**
- tabel over:
  - `shared nu`
  - `shared senere`
  - `app-only`
  - `ikke besluttet`

**Lukket med**
- konkret matrix i `AUTH_AND_DATA_OWNERSHIP.md`
- produktoversættelse i `ONE_PRODUCT.md`
- eksplicit placering af `visited`, `visitedDate`, noter, reviews, fotos, weekend-plan og achievements

### T-10 Integration release checklist
**Status:** Lukket
**Prioritet:** Mellem
**Bygger på:** `NEXT-03`

**Formål**
- gøre integrationen verificerbar som reel leverance

**Primære områder**
- `Tribunetour/Tribunetour_docs/docs/RELEASE.md`
- `Tribunetour/Tribunetour_docs/docs/HYBRID_SYNC_TEST_PLAN.md`
- evt. ny sektion i `INTEGRATION_STATUS.md`

**Leverance**
- checkliste for web build, app build, login, bootstrap, visited sync og reference-data konsistens

**Lukket med**
- `Integration Release Checklist` skrevet ind i `RELEASE.md`
- `INTEGRATION_STATUS.md` opdateret til at pege på checklisten som aktuel go/no-go

---

## Sprint 5: Release Completion

Dette sprint er den næste konkrete arbejdspakke, hvis målet er en release hvor Tribunetour opleves som ét produkt hele vejen rundt og ikke kun på kernebrugerdata.

Fokus er:
- `photos`
- `weekend plan`
- progression/achievements på web

#### S5-01 Beslut foto-scope for release
**Status:** Låst

**Mål**
- gøre billeder til del af web-release

**Leverance**
- shared photos-kontrakt
- første webflow for billeder
- app/web sync for billeder
- sanity-test for billeder på tværs

#### S5-02 Beslut weekend-plan-scope for release
**Status:** Låst

**Mål**
- gøre weekend-plan til del af web-release

**Leverance**
- shared plan-model
- første webflow for plan/weekend-plan
- app/web sync for plan
- sanity-test for plan på tværs

#### S5-03 Beslut webens progression/achievements
**Status:** Låst

**Mål**
- gøre progression/achievements til del af web-release

**Leverance**
- fælles produktregel for progression
- webvisning af progression/achievements
- afklaring af hvilke dele der er afledte, og hvilke der er eksplicit shared data

#### S5-04 Opdatér release-check og produktcopy
**Status:** Planlagt

**Mål**
- få release-checken til at matche den endelige produktafgrænsning

**Leverance**
- opdateret `RELEASE.md`
- opdateret `INTEGRATION_STATUS.md`
- produktcopy uden skjulte integrationsforbehold

---

## Anbefalet implementeringsrækkefølge

Hvis arbejdet skal tages i den mindst risikable rækkefølge, er dette den anbefalede sekvens:

1. `T-01` Reference-data source of truth
2. `T-02` Web referenceData-modul
3. `T-03` Reference-data validation flow
4. `T-04` Shared visited steady-state decision
5. `T-05` App bootstrap UX
6. `T-06` App sync error handling
7. `T-07` Docs and README alignment
8. `T-08` Reduce runtime modes
9. `T-09` Shared vs app-only data matrix
10. `T-10` Integration release checklist

### Praktisk læsning af rækkefølgen
- først lukkes risikoen for nyt data-mismatch
- derefter låses den fælles sandhed for `visited`
- bagefter ryddes overgangslaget op
- til sidst gøres løsningen releasebar og tydeligt dokumenteret

---

## Arbejdsnoter

Dette dokument bør opdateres når:
- en opgave er lukket
- en opgave skifter prioritet
- en beslutning ændrer arkitekturen
- scope for web eller app ændres
