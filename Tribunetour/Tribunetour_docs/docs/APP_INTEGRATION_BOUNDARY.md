# App Integration Boundary

## Formål
Dette dokument fastlægger den tekniske grænse for den nuværende iOS-app, mens web og backend bevæger sig mod et fælles produktunivers.

Målet er:
- at appen fortsat kan releases undervejs
- at reference-data kan opdateres uden at bryde integrationsarbejdet
- at vi ved præcis hvor appen senere kan kobles på shared modeller

## Nuværende app-arkitektur

### Visited
Appens visited-spor er i dag:
- local-first
- lagret i `VisitedStore`
- persistet i `UserDefaults`
- synket via brugerens private CloudKit-database

Appen har nu desuden eksplicitte boundary-lag for de shared felter, der er løftet ud af direkte view-kobling:
- `AppNotesStore`
- `AppReviewsStore`
- `AppPhotosStore`
- `AppWeekendPlanStore`

Centrale filer:
- `VisitedStore.swift`
- `CloudSync.swift`

### Weekend plan
Weekend plan er et separat brugerdata-spor:
- local-first i appen
- synk via privat CloudKit
- viewlaget går nu via `AppWeekendPlanStore` i stedet for direkte mod den rå plan-store

Central fil:
- `CloudPlanSync.swift`

### Fixtures / reference-data
Fixtures er allerede arkitektonisk mere adskilte fra brugerdata:
- appen kan hente remote dataset via `RemoteFixturesProvider`
- fallback er lokal bundled CSV

Central fil:
- `RemoteFixturesProvider.swift`

Det er vigtigt, fordi reference-data-sporet allerede er mere egnet til løbende opdateringer uden at blande sig ind i visited-integrationen.

## Hård grænse mellem to spor

### Spor A: Reference-data
Dette spor skal kunne ændres undervejs uden at vælte resten:
- fixtures
- remote dataset URL
- lokale fallback-filer
- visning af reference-data i appen

### Spor B: Brugerdata
Dette spor skal behandles mere konservativt:
- visited
- visitedDate
- notes
- reviews
- photos
- weekend plan

Praktisk regel:
- den kommende app-opdatering bør kun røre spor A, medmindre der er meget stærk grund til andet

## Hvor appen senere skal kobles på shared modellen

### Reference-data
Appen bør fortsat betragte reference-data som separat fra brugerdata.

Det betyder:
- `Fixture`, `clubId`, `venueClubId`, `homeTeamId`, `awayTeamId` skal forblive stabile og fælles på tværs af app og web
- reference-data kan udskiftes eller opdateres uden migration af brugerdata

### Visited
Appen skal senere kobles på shared `visited`-modellen bag en ny adapter.

Det bør ikke ske ved at sprede Supabase/backend-logik direkte ind i views.

Det bør ske ved at indføre et nyt lag, fx:
- `VisitedRepository`
eller
- `VisitedSyncAdapter`

Dette lag skal være den eneste del af appen, der kender forskellen mellem:
- lokal data
- privat CloudKit
- shared backend-model

## Hvad der ikke skal ændres i næste app-opdatering
For at holde systemet stabilt bør næste app-opdatering ikke ændre på:
- `VisitedStore.Record` som helhed
- merge-reglerne i `VisitedStore`
- CloudKit-record typerne `VisitedStadium` og `PhotoVisited`
- weekend plan sync-modellen

Det betyder ikke, at de er endelige.
Det betyder kun, at de ikke bør være mål for den næste kortsigtede app-release.

Det er dog acceptabelt at flytte merge- og migrationsautoritet bag en separat policy, så længe den nuværende adfærd bevares.

## Hvad der gerne må ændres i næste app-opdatering
Disse ting er sikre kandidater:
- opdatering af kampprogram
- ændring af remote fixtures dataset
- justering af fixtures fallback-data
- forbedringer i fixtures-præsentation
- reference-data-validering i build/release flow

## Senere integrationsstrategi for appen

### Fase 1
Hold appens nuværende visited-model stabil.

### Fase 2
Indfør en app-side boundary omkring visited, uden at ændre UI-adfærd.

Det betyder:
- `VisitedStore` bør senere afhænge af en protokol eller adapter
- ikke direkte af CloudKit alene

### Fase 3
Lad appen læse shared visited-model som supplement, ikke total erstatning i første omgang.

Mulige overgangsretninger:
- shared backend som read-through source
- lokal model som cache
- gradvis migration af enkelte felter

Status:
- appen har nu en eksplicit `SharedVisitedSyncBackend` klientstruktur i koden
- shared backend-seamet har request/response-mapping, auth-token seam og soft-delete via `visited = false`
- appen har et separat `AppAuthSession` seam, så token ikke senere skal hentes direkte fra views eller globals
- appen har også en `HybridVisitedSyncBackend`, der kan lade appen forblive primær og senere spejle writes til shared backend
- appen har nu også særskilte boundaries for `notes`, `reviews` og `photos`, så disse ikke længere skal kobles på shared backend direkte fra viewlaget
- ingen af de shared-baserede backends er aktive i runtime endnu
- de bruges kun som forberedte seams til næste hybridfase

### Fase 4
Beslut om CloudKit visited skal:
- udfases
- spejles
- eller fortsætte som hybridlag i en overgangsperiode

## Midlertidig brugeradvarsel ved første login
Når appen senere får login og shared visited-model bliver autoritativ, skal brugeren have en kortvarig førstegangsbesked.

Formål:
- gøre source-of-truth skiftet tydeligt
- reducere risiko for at brugeren misforstår forskelle mellem gammel app-data og ny fælles model

Regel:
- advarslen skal kun vises i en kort overgangsperiode
- helst kun første gang brugeren logger ind efter skiftet
- derefter skal den fjernes igen, så den ikke bliver permanent produktstøj

Anbefalet budskab:
- at Tribunetour nu synkroniserer besøg på tværs af app og web
- at appen tidligere var den primære kilde
- at brugeren bør kontrollere sine besøg første gang efter login

## Første login i appen: bootstrap-ansvar
Ved første login i appen skal appen ikke forsøge at merge webens visited-data ind i lokale app-data.

Reglen er:
- appen er autoritativ ved første bootstrap
- shared backend skal bringes i overensstemmelse med appens snapshot
- først derefter går brugeren over i almindelig fælles sync

Det betyder for app-flowet:
1. hent `migration-state` fra backend efter login
2. hvis bootstrap kræves:
   - vis engangsadvarsel
   - kræv aktiv bekræftelse
3. send komplet bootstrap-snapshot fra appens `VisitedStore`
4. vent på backend-bekræftelse
5. skift derefter til normal shared sync

Det betyder også:
- der skal være en tydelig forskel i koden mellem:
  - almindelig visited sync
  - bootstrap-migration

Bootstrap er en særskilt operation og må ikke gemmes som bare endnu et sæt almindelige `PUT /visited/:clubId` writes.


## Source Of Truth i overgangsperioden
Indtil en egentlig fælles visited-sync er implementeret end-to-end, gælder:
- appen er source of truth for eksisterende brugerdata omkring besøg
- web skal kommunikere dette tydeligt til brugeren
- shared backend-modellen er på vej til at blive fælles lag, men skal ikke antages at være autoritativ i konflikt med allerede korrekte app-data endnu

Det betyder i praksis:
- app-data må ikke ukritisk nedprioriteres til fordel for web-ændringer under migrationen
- brugerkommunikation på web bør fortælle, at appen stadig er den sikre kilde, hvis der opstår uoverensstemmelser

## Praktisk release-regel
Så længe den næste app-release kun rører reference-data-sporet, er integrationsarbejdet på web/backend ikke en blocker.

Appen har nu også et runtime-flag for visited sync mode. Det gør det muligt at teste hybrid/shared forberedelse på enkelte enheder uden at ændre standardadfærden for alle brugere.

Det er den vigtigste beslutning i dette dokument.

## Hvad vi bør gøre bagefter
Når din reference-data-appopdatering er landet, er det rigtige næste app-arbejde:
1. definere en app-side adapter for visited
2. flytte CloudKit-kendskab bag adapteren
3. først derefter begynde egentlig app/shared visited-konvergens
4. bruge `HYBRID_SYNC_TEST_PLAN.md` som kontrolleret intern test-runbook før runtime-skift aktiveres bredere

## Konklusion
Appen er ikke i vejen for det samlede produktunivers.
Men den skal behandles med en tydelig boundary:
- reference-data kan opdateres nu
- brugerdata skal kobles på shared model senere, kontrolleret og lagdelt
