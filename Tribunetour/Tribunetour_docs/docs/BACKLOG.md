# Tribunetour Backlog

Dette dokument er den løbende, samlede backlog for appen.  
Opdateres løbende sammen med sprint-arbejdet.

---

## Status Snapshot
- **Fase:** App-first (før backend/web)
- **Aktuel sprintretning:** Sprint 5.x (EPIC E-light + D-light)
- **Næste beslutningspunkt:** App Store v1 launch vs. platform foundation
- **Næste store fase:** Login/backend/web-fundament (EPIC A) efter første App Store-release
- **Platform-retning:** se `ONE_PRODUCT.md` for fælles retning mellem app og web

---

## Done (højdepunkter)
- Kerneflow: Stadions, Kampe, Plan, Min tur
- Filtrering/sortering/søgning inkl. afstand
- Kampdetaljer + link til stadiondetaljer
- Lokal persistens + iCloud sync (visited + plan)
- Review v1 i stadiondetalje:
  - kategorier, score, kategori-noter, opsummering, tags
- Fotos v1:
  - upload, lokalt galleri, fullscreen, swipe, billedtekst, sletning
- Stats v1:
  - anmeldelser, fotos, progression
- Achievements v1:
  - lokale milestones + unlock/progress
- Notifikationer v1:
  - lokal torsdag kl. 20 weekend-påmindelse (fredag→mandag)
  - lokal mandag kl. 20 midtuge-påmindelse (tirsdag→torsdag)
  - bruger-opt-in toggles for påmindelser
- Interne værktøjer:
  - skjult tools-side (4 tap på "Besøgt X / Y")
  - backup/import, reset achievements, force test-notifikationer

---

## In Progress (Sprint 5.x)
- Backlog-konsolidering og prioritering frem mod næste sprint
- App Store launch-spor afgrænset som separat leverance
- Facebook-plan dokumenteret som fast kanalspor for post-launch synlighed

---

## Post-release kandidater

1. **G-FacebookPlan (Medium)**
   - Brug Facebook som personlig fortællings- og release-kanal
   - Formål:
   - fortælle historien bag Tribunetour
   - skabe stabil synlighed omkring nye features, stadionture og releases
   - sende interesserede videre til App Store og `tribunetour.dk`
   - Første konkrete arbejde:
   - billedbank med app screenshots og stadionbilleder
   - 4-6 ugers enkel content-plan
   - faste opslagstyper: historien bag, produktnyt, stadiondagbog, milepæle
   - Se:
   - `FACEBOOK_PLAN.md`

2. **Ops-NightlyRegression (Høj)**
   - Daglig automatisk regression for web og app via CI/macOS runner
   - Formål:
   - gøre regressionskørsel uafhængig af manuel start
   - få faste signaler på auth, sync og kerneflows

3. **P-MultiLeagueExperiment (Medium/Høj)**
   - Byg multi-league support som et kontrolleret udvidelseslag
   - Første konkrete næste pack:
   - Tyskland (`Bundesliga`, `2. Bundesliga`, `3. Liga`)
   - Næste trin:
   - lås første tyske klub-id-draft
   - lav første reference-data-draft for tyske stadioner/koordinater
   - Formål:
   - validere om ekstra ligaer skaber reel produktværdi
   - holde Danmark som kerneprodukt
   - kunne aktivere/deaktivere funktionen uden stor refaktorering
   - Web-krav:
   - funktionen skal være login-bundet
   - ikke-loggede brugere ser kun Danmark
   - loggede brugere får adgang via brugerflag/entitlement
   - Se:
   - `MULTI_LEAGUE_EXPERIMENT.md`
   - `GERMANY_LEAGUE_PACK.md`
   - `GERMAN_CLUB_ID_MAPPING_DRAFT.md`

4. **P-ClubIdMigration (Høj)**
   - Lås en canonical club id-policy før første ekstra league pack
   - Formål:
   - undgå id-kollisioner på tværs af lande
   - flytte korte forkortelser ud af den primære nøgle
   - gøre Tyskland sikkert at importere som næste pack
   - Første arbejde:
   - audit af danske ids
   - mapping fra nuværende ids til nye canonical ids
   - plan for fixture- og brugerdata-migration
   - Næste trin:
   - kør Supabase backfill af `visited`, `notes`, `reviews` og `photos`
   - Se:
   - `CLUB_ID_POLICY.md`
   - `DANISH_CLUB_ID_AUDIT.md`
   - `DANISH_CLUB_ID_MAPPING_DRAFT.md`
   - `CLUB_ID_MIGRATION_PLAN.md`
   - `CLUB_ID_SUPABASE_BACKFILL.md`

5. **Ops-PostMigrationCleanup (Høj)**
   - Luk oprydningsspor efter første canonical `club_id`-migration
   - Formål:
   - gøre migrationen stabil for både live app, ny app-build og web
   - reducere midlertidige compatibility-lag når det er sikkert
   - Konkrete delspor:
   - migrér foto-storage-paths i `stadium-photos` fra legacy mapper til canonical mapper
   - fjern behovet for legacy photo path fallback, når storage-migration er verificeret
   - gennemgå `visited`-sync mod live App Store-build og beskyt mod forkert backfill/overskrivning
   - dokumentér hvilke shared feeds der skal forblive bagudkompatible, indtil ny appversion er bredt ude
   - Verifikation:
   - app, web og live release-build skal vise samme `visited`, `reviews` og `photos`
   - filtre og counts må ikke drive fra hinanden efter sync

---

## Release Checklist (Sprint 5.x)

Mål: Lukke sprintet med en testbar, release-klar baseline.

- [x] **R1 Build & startup**
  - Ren build uden compile-fejl
  - App starter uden blokkerende fejl
- [x] **R2 Data-load**
  - `stadiums.csv` og `fixtures.csv` loader korrekt
  - Ingen tom state ved normal opstart med gyldige datafiler
- [x] **R3 Photo sync (single-device reinstall)**
  - Upload 10-15 billeder på mindst 2 stadions
  - Slet app + installer igen
  - Verificér at alle billeder og captions kommer tilbage
- [x] **R4 Photo sync (edge cases)**
  - Slet et billede lokalt og verificér sync
  - Redigér caption og verificér persistence efter relaunch
- [x] **R5 Review persistence**
  - Udfyld score + valgfri kategori-noter
  - Verificér restore efter relaunch/reinstall
- [x] **R6 Achievements UX**
  - Unlock-flow fungerer
  - Reset debug-funktion fungerer
  - Toast viser korrekt ved flere samtidige unlocks
- [x] **R7 CloudKit sanity**
  - Ingen kritiske CK-fejl (`Invalid Arguments`, schema mismatch)
  - Eventuelle system-framework logs vurderet som non-blocking
- [x] **R8 Docs & release hygiene**
  - `CHANGELOG.md` opdateret med sprintens ændringer
  - `RELEASE.md` opdateret med go/no-go kriterier

---

## Næste Sprint (forslag)

Mål: Reducere release-friktion, styrke datakvalitet og gøre appen mere driftssikker.

1. **A-RemoteFeed (Høj)**
   - Remote data-feed til fixtures/stamdata uden nyt app-build
   - Signeret dataversion + fallback til seneste valide dataset
   - **Estimat:** 5-8 dage
2. **A-ConflictPolicy (Høj)**
   - Klar merge-policy for CloudKit-konflikter (feltniveau hvor muligt)
   - Beskyttelse mod clock-skævhed og race-condition i multi-device flow
   - **Estimat:** 2-4 dage
3. **Q-RegressionPack (Høj)**
   - Automatiserede tests for timezone, notifikationsvinduer, fotosync, og merge
   - Baseline regression suite før hver release
   - **Estimat:** 3-5 dage
4. **Ops-InternalToolsGuard (Medium)**
   - Flyt interne værktøjer bag debug/feature-flag så de ikke eksponeres utilsigtet
   - **Estimat:** 1-2 dage

---

## App Store v1 (anbefalet rækkefølge)

Mål: få første offentlige release ud, før større platformmigrering.

1. **AS1 Release lock (Høj)**
   - Lås feature-scope for første App Store-version
   - Kun bugfixes, metadata, compliance og mindre UX-polish
   - Status: scope låst i `RELEASE.md`
2. **AS2 Submission readiness (Høj)**
   - App Store metadata, screenshots, privacy, support-URL, version/build
   - Verificér permission-tekster og kerneflows i Release-build
3. **AS3 Post-launch observation (Høj)**
   - Saml første rigtige brugerfeedback fra App Store/TestFlight
   - Brug feedback som input til platform-prioritering
4. **AS4 Platform foundation bagefter (Høj)**
   - Start `Supabase + web + shared backend` som næste større spor

---

## Sprintplan (Dag 1-3 + DoD)

### Dag 1
1. **A-RemoteFeed: design + skeleton**
   - Definér dataformat (`fixtures` + metadata/version/signatur)
   - Implementér read-path med fallback til lokal bundle-data
   - DoD:
   - App loader data fra lokal fallback uden regressions
   - Remote-parser fejler kontrolleret (ingen crash, tydelig log)
2. **Ops-InternalToolsGuard: afgrænsning**
   - Flyt adgang til interne tools bag compile-flag/feature-flag
   - DoD:
   - Tools er skjult i production-konfiguration
   - Tools virker stadig i debug/test-konfiguration

### Dag 2
1. **A-RemoteFeed: versionering + rollback**
   - Gem “sidst kendte valide dataset” lokalt
   - Implementér rollback hvis ny payload er ugyldig
   - DoD:
   - Ugyldig payload medfører rollback til seneste valide data
   - Version fremgår af debuglog og kan verificeres manuelt
2. **A-ConflictPolicy: merge-regler**
   - Indfør tydelige merge-regler pr. felt (visited/date/notes/review/photos)
   - Håndtér serverRecordChanged deterministisk
   - DoD:
   - Multi-device konflikt ender i forudsigeligt resultat
   - Ingen tab af fotos/review ved normal konflikt-retry

### Dag 3
1. **Q-RegressionPack: kritiske tests** ✅
   - Tilføj testcases for timezone, notif-vinduer, fotosync, merge
   - DoD:
   - Testpakke kan køres lokalt før release
   - Kritiske flows har mindst én regression-test hver
2. **Sprint hardening + dokumentation** ✅
   - Opdater `CHANGELOG.md`, `RELEASE.md`, `ARCHITECTURE.md`
   - Go/No-go gennemgang
   - DoD:
   - Build grøn
   - Release-noter opdateret
   - Kendte risici dokumenteret

---

## Dag 1: Konkrete tasks pr. fil

### A-RemoteFeed: design + skeleton

1. **Ny fil: `Tribunetour/RemoteDataModels.swift`**
   - Opret model for remote payload:
   - `RemoteDatasetEnvelope` (version, generatedAt, checksum/signature, fixtures)
   - `RemoteFixtureDTO` med felter der matcher nuværende `Fixture`
   - Mapping-funktion fra DTO -> `Fixture`

2. **Ny fil: `Tribunetour/RemoteFixturesProvider.swift`**
   - Opret provider med ansvar for:
   - Hentning fra remote endpoint (`URLSession`)
   - Decode/validering
   - Fallback til lokal bundle-data ved fejl
   - Returnér både `fixtures` og metadata (kilde/version)

3. **Fil: `Tribunetour/AppState.swift`**
   - Erstat direkte bundle-load af fixtures med provider-flow
   - Behold `stadiums.csv` load som i dag (kun fixtures flyttes i første step)
   - Tilføj let telemetry/debug-log:
   - “fixtures source: remote/local-fallback”
   - “fixtures version: x”

4. **Fil: `Tribunetour/DebugLog.swift`**
   - Tilføj standardiserede log helpers til data-source/version, så logs er ensartede

5. **Fil: `Tribunetour/FixturesCSVImporter.swift`**
   - Ingen funktionel ændring
   - Kun små justeringer hvis nødvendigt for at kunne kaldes fra provider som fallback

6. **Fil: `TribunetourTests/TribunetourTests.swift`**
   - Tilføj test for DTO->Fixture mapping (gyldig payload)
   - Tilføj test for fallback-case (invalid payload -> local fallback trigger)

### Ops-InternalToolsGuard: afgrænsning

1. **Fil: `Tribunetour/ContentView.swift`**
   - Gate “4 taps -> InternalToolsView” bag compile-flag
   - Forslag: `#if DEBUG` omkring tap-counter + sheet navigation

2. **Fil: `Tribunetour/InternalToolsView.swift`**
   - Ingen større ændring i selve viewet
   - Sikr at viewet kun kan nås i debug/test-builds via compile-gate

3. **Fil: `Tribunetour/TribunetourApp.swift`**
   - Hvis der er global routing/entrypoints til tools, beskyt dem bag samme flag

4. **Fil: `Tribunetour/Tribunetour_docs/docs/RELEASE.md`**
   - Tilføj check i release-flow:
   - “Internal tools inaccessible in production build”

### Dag 1 afslutnings-check (kørsel)

1. Byg appen (`BuildProject`) og verificér grøn build.
2. Verificér manuelt:
   - App starter med fallback hvis remote ikke er tilgængelig.
   - Debug-build: Internal tools kan stadig åbnes.
   - Production-konfiguration: Internal tools er ikke tilgængelig.
3. Opdater `CHANGELOG.md` med “remote fixtures skeleton + internal tools guard”.

---

## Dag 2: Konkrete tasks pr. fil

### A-ConflictPolicy: merge-regler (CloudKit)

1. **Fil: `Tribunetour/VisitedStore.swift`**
   - Indfør eksplicit merge-policy pr. felt:
   - `visited`: OR-logik (true vinder over false)
   - `visitedDate`: tidligste gyldige dato vinder (hvis begge findes)
   - `notes`: seneste `updatedAt` vinder
   - `review`: seneste `review.updatedAt` vinder
   - `photoFileNames/photoMetadata`: union + seneste `updatedAt` pr. fil
   - Lav dedikeret merge-funktion, fx `mergeRecords(local:remote:)`

2. **Fil: `Tribunetour/CloudSync.swift`**
   - Stram håndtering af `serverRecordChanged`:
   - Retry med fetch-latest -> merge -> save
   - Maks retrypolitik + tydelig debuglog ved endeligt failure
   - Sikr at foto-upsert også følger samme retry/merge-princip

3. **Fil: `Tribunetour/DebugLog.swift`**
   - Tilføj standard logs for konfliktforløb:
   - “merge-start”, “merge-rule-used”, “merge-result”, “retry-count”

4. **Fil: `Tribunetour/CloudPlanSync.swift` og `Tribunetour/WeekendPlanStore.swift`**
   - Verificér at plan-sync følger tilsvarende deterministisk conflict-behandling
   - Hvis ikke: tilføj minimum samme retry-strategi

### Q-RegressionPack: testcases til Dag 2

1. **Fil: `TribunetourTests/TribunetourTests.swift`**
   - Test: `visited` merge (true + false => true)
   - Test: `visitedDate` merge (ældste dato bevares)
   - Test: `notes` merge (nyeste timestamp vinder)
   - Test: `review` merge (nyeste review vinder)
   - Test: foto-merge (union + metadata-vinder)

2. **Fil: `TribunetourTests/MatchesFilteringTests.swift`**
   - Ingen stor ændring forventet
   - Tilføj evt. regression der sikrer at dataload/sortering stadig virker efter merge-refactor

### Dag 2 afslutnings-check (kørsel)

1. Build grøn (`BuildProject`).
2. Testpakke grøn for nye merge-tests.
3. Manuel sanity:
   - Simulér konfliktforløb (to opdateringer på samme klub) og verificér deterministisk resultat.
4. Dokumentation:
   - Opdater `ARCHITECTURE.md` med merge-regler.
   - Opdater `DATA_MODEL.md` med feltniveau merge-adfærd.

---

## Dag 3: Konkrete tasks pr. fil

### Q-RegressionPack: afslutning + stabilisering

1. **Fil: `TribunetourTests/TribunetourTests.swift`**
   - Tilføj tests for remote feed fallback-flow:
   - valid remote payload -> bruges
   - invalid remote payload -> fallback til lokal data
   - rollback til “senest valide dataset”

2. **Fil: `TribunetourTests/MatchesFilteringTests.swift`**
   - Tilføj timezone-regression:
   - fixtures efter sommertid vises med korrekt lokal tid
   - filtrering “i dag / 3 dage / uge / måned” er stabil i `Europe/Copenhagen`

3. **Fil: `Tribunetour/WeekendOpportunityNotifier.swift`**
   - Verificér trigger-vinduer med tests eller testbar helper:
   - mandag 20:00 -> tirsdag-torsdag vindue
   - torsdag 20:00 -> fredag-mandag vindue
   - ingen schedule når count = 0

### Release hardening / docs

1. **Fil: `Tribunetour/Tribunetour_docs/docs/ARCHITECTURE.md`**
   - Opdater arkitekturdiagram/tekst:
   - AppState -> Remote provider -> fallback chain
   - Cloud merge-policy ansvar og datakilde-prioritet

2. **Fil: `Tribunetour/Tribunetour_docs/docs/DATA_MODEL.md`**
   - Dokumentér:
   - dataset metadata/versionering
   - merge-regler pr. felt
   - forventet adfærd ved konflikt

3. **Fil: `Tribunetour/Tribunetour_docs/docs/CHANGELOG.md`**
   - Tilføj sprintens tekniske ændringer i klart “customer + technical” format

4. **Fil: `Tribunetour/Tribunetour_docs/docs/RELEASE.md`**
   - Opdater release-gate:
   - remote feed fallback test
   - internal tools guard i production
   - merge regression suite grøn

### Dag 3 afslutnings-check (go/no-go)

1. Build grøn (`BuildProject`).
2. Alle regression-tests grønne.
3. Manuel smoke-test:
   - Stadions/Kampe/Plan/Min tur åbner uden regressions
   - Data load fungerer ved både remote succes og fallback
   - Notifikationer respekterer toggles
4. Go/No-go beslutning dokumenteret i `RELEASE.md`.

---

## Next Up (prioriteret efter sprintforslag)
1. **A-RemoteFeed:** Remote fixtures/stamdata + versionering/rollback
2. **A-ConflictPolicy:** Robust CloudKit merge-strategi
3. **Q-RegressionPack:** Kritiske regression tests før release
4. **Ops-InternalToolsGuard:** Beskyt interne værktøjer i production builds
5. **D18-D21:** Achievement polish + flere tiers
6. **E24-E25:** Review polish (hurtigere input, rediger/slet-flow)
7. **C20:** Små UX-polish-opgaver (haptics, swipe-actions, tom-tilstande)
8. **N6:** Notification center i appen (seneste sendte påmindelser)

### Post-release driftsløft
1. **Ops-NightlyRegression (Høj)**
   - Daglig automatisk regression uden manuel start fra Codex eller udviklermaskine
   - Web-suite på schedule i CI
   - App-suite på macOS runner i CI
   - Dedikeret testkonto og stabil seed-data
   - Artifact-upload og fejlnotifikationer ved rød kørsel
   - Mål:
   - Release-gaten kan senere baseres på faste automatiske natlige kørsler
   - Regression opdages proaktivt i drift, ikke først ved næste release

---

## Push-notifikationer (status)
> N1/N2/N4 er påbegyndt/leveret i lokal version. Nedenfor er næste trin.

1. **N1 (done):** Lokal notifikation ved ny achievement unlock (test-flow klar)
2. **N2 (done):** Weekend-signal torsdag kl. 20
3. **N4 (done):** Notifikationsindstillinger (opt-in toggles)
4. **N3 (next):** Reminder: "Næste kamp på stadion du mangler"
5. **N5 (next):** Ugentlig digest (søndag aften)

---

## Later (strategisk)

### EPIC A – Login / backend / web
- Login-strategi (Apple/email)
- Brugerprofil
- Backend-beslutning + migrering
- API/read-model til web
- Remote data-feed til app (kampprogram/stamdata), så `fixtures` kan opdateres uden nyt app-build
- Fallback-strategi for data-versionering (seneste valide dataset + rollback)

### EPIC F/G – Social + ranking
- Deling af besøg/billeder/reviews
- Gruppeture/invite
- Leaderboards (med privacy/opt-in)

### Branding/visuals
- Klublogoer
- Rækkelogoer

---

## Working Rules
- Fokus på app-værdi først, backend efter stabil kerne.
- Små, releasebare increments med tydelig DoD.
- Backlog opdateres i dette dokument ved større feature-ændringer.
