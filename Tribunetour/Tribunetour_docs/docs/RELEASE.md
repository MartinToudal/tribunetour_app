# Release Notes – Sprint 5.x

Version: 0.1.0 (7) planned submission

## Formål
Lukke stabilitet, performance og UX-polish med fokus på daglig drift i TestFlight.

## Release scope (Sprint 5.x)
- Fotos v1 med CloudKit-sync (upload, sletning, captions, restore)
- Review v1 (scores, valgfri kategori-noter, summary/tags)
- Achievements v1 (unlock/progress + toast UX)
- Løbende stabiliseringsfixes i sync-flow

## Go / No-Go kriterier
- **Build:** Grøn build uden compile-fejl
- **Tests:** Regressionstest grøn (merge + notifier-vinduer + timezone)
- **Data:** `stadiums.csv` + `fixtures.csv` loader stabilt
- **Photo sync:** 10-15 billeder pr. stadion overlever reinstall
- **Review:** Reviewdata persisterer efter relaunch/reinstall
- **Achievements:** Unlock + reset + multi-unlock-toast virker
- **CloudKit:** Ingen kritiske schema-/argument-fejl i normal brugerflow

## Kendte ikke-blokerende logs
Følgende log-typer kan forekomme i debug uden at være release-blockers:
- `PerfPowerTelemetryClientRegistrationService` sandbox/connection warnings
- `PPSClientDonation` / `SpringfieldUsage` permission warnings
- `CAMetalLayer ignoring invalid setDrawableSize`
- `Potential Structural Swift Concurrency Issue: unsafeForcedSync ...`

## Release beslutning
- **Klar til TestFlight:** når alle Go/No-Go kriterier er opfyldt
- **Skal holdes tilbage:** hvis photo/review restore fejler eller CloudKit giver kritiske fejl

## App Store Launch Checklist (v1)
Mål: sende første App Store-version uden at blokere næste platformfase.

## App Store v1 Scope Lock

### Inkluderet i v1
- Stadions: liste, kort, søgning, filtrering og visited-status
- Kampe: kommende kampe, søgning/filtrering og kampdetalje
- Plan: planlægning af kampe og sammenhæng til kamp/stadion-flow
- Min tur: statistik, progression og achievements
- Reviews v1: scores, noter, summary/tags
- Fotos v1: galleri, captions, sletning og restore
- Lokale notifikationer v1: weekend + midtuge + opt-in toggles
- CloudKit for nuværende personlige app-flows

### Ikke inkluderet i v1
- Login / brugerprofiler
- Rangliste / leaderboard
- Sociale features, deling og grupper
- Supabase-migrering
- Ny webplatform / `tribunetour.dk` relaunch
- Remote shared backend som primær datakilde
- Fuld udskiftning af CloudKit

### Tilladt før submission
- Bugfixes
- Tekst/copy
- Små UX-forbedringer uden model- eller arkitekturændringer
- App Store metadata og compliance-arbejde

### Ikke tilladt før submission
- Nye store features
- Ny auth/backend-struktur
- Datamodelændringer der kræver migreringsstrategi
- Større ombygning af sync eller persistence

- **Produkt-scope låst**
- Ingen nye store features eller backend-skift før submission
- Kun bugfixes, copy, metadata og mindre UX-polish
- **Teknisk kvalitet**
- Grøn build i Release-konfiguration
- Grøn lokal regressionstest
- Ingen kendte blokkerende crashes i kerneflow: Stadions, Kampe, Plan, Min tur
- **Data og sync**
- `stadiums.csv` og `fixtures.csv` loader stabilt
- CloudKit fungerer for eksisterende personlige flows
- Appen håndterer manglende iCloud-konto uden crash eller låst UI
- **App Store compliance**
- App Privacy udfyldt korrekt i App Store Connect
- Permissions-tekster er på plads og forståelige
- Screenshots, app-beskrivelse, keywords og support-URL er klar
- Version/build er konsistent mellem Xcode og App Store Connect
- **Go / No-Go for submission**
- Go: stabil kerneoplevelse, ingen blokkerende sync-fejl, metadata klar
- No-Go: reproducérbart datatab, crash i kerneflow, uklare privacy/permisson-forhold

## Efter Launch
- Platform-arbejde (`Supabase + web + shared backend`) kører som separat spor
- Første platformmål er shared read-data, ikke fuld migration af alle app-data

## Integrationsstatus efter App Store-spor

Den aktuelle integrationsretning er nu:
- web og app deler auth-retning
- web og app deler `visited`-retning
- shared backend er besluttet som steady-state for `visited` efter bootstrap
- reference-data er samlet på kontrakt- og valideringsniveau, men endnu ikke på én fuld pipeline

Det betyder for release-arbejde:
- App Store-sporet kan stadig vurderes som app-first releasehistorik
- men videre produktarbejde skal beskrives som integration mod ét samlet produkt

### Hvad der ikke længere bør stå i releasebeskrivelser uden præcisering
- at appen generelt er den permanente sandhed for `visited`
- at web er et rent separat sideprojekt
- at login/backend kun er et fremtidsspor

### Hvad der bør stå i stedet
- appen er den mest modne flade
- web er den næste produktflade
- `visited` er i overgang, men steady-state er låst
- reference-data er under konsolidering mod én pipeline

## Integration Release Checklist

Denne checkliste er den aktuelle go/no-go liste for integrationen mellem app og web.

### Hurtig sanity-rutine
Denne rutine er den hurtigste måde at bekræfte, at integrationskernen stadig holder efter ændringer.

Kør den i denne rækkefølge:
1. byg web og app grønt
2. åbn appen som gæst og bekræft at centrale flader loader
3. log ind i appen og bekræft at session genoptages korrekt
4. gennemfør bootstrap med en bruger uden shared `visited`, hvis det er den type release der testes
5. markér et stadion som besøgt i appen og bekræft ændringen på web
6. markér et stadion som besøgt på web og bekræft ændringen i appen efter normal aktivering/fokus
7. markér et stadion som ubesøgt den ene vej og bekræft at det forbliver stabilt den anden vej
8. bekræft at app-only data stadig kun opfører sig som app-only data

Resultatet skal læses sådan:
- hvis alt ovenfor er grønt, er integrationsfundamentet grønt
- hvis noget fejler, skal fejlen placeres som enten `auth`, `bootstrap`, `visited`, `reference-data` eller `app-only data`
- manglende realtime er ikke i sig selv en blocker, hvis fokus- og aktiveringsflowet virker som forventet
- kendte begrænsninger skal beskrives eksplicit, men må ikke blandes sammen med reelle blockers

### 1. Build og validering
- web build er grøn med `npm run build`
- reference-data validering er grøn med `npm run validate:data`
- iOS-build er grøn med `xcodebuild -project 'Tribunetour.xcodeproj' -scheme 'Tribunetour' -destination 'generic/platform=iOS' -derivedDataPath /tmp/TribunetourDerivedData -allowProvisioningUpdates build`
- ingen nye compile-fejl eller regressionswarnings i de seneste integrationsændringer

### 2. Reference-data konsistens
- `Stadions`, `Kampe`, stadiondetaljer og kampdetaljer peger på samme IDs
- webens `referenceData`-lag er eneste læsevej for reference-data i produktfladerne
- fixtures og stadions kan verificeres mod samme seed-/kontraktdata
- kendte sanity checks for ID’er, relationer og koordinater består

### 3. Auth
- login virker på web
- login/callback virker i app
- appen kan genoptage en eksisterende session
- udløbet session giver en forståelig fejl eller ny loginvej, ikke tavs fejltilstand

### 4. Bootstrap for `visited`
- en bruger uden shared `visited` kan gennemføre bootstrap fra appen
- bootstrap-copy forklarer tydeligt, at appens eksisterende visited-status opretter den fælles model første gang
- bootstrap afsluttes uden tab af lokal visited-status
- appen skifter bagefter korrekt til shared `visited`-retning

### 5. Tværflade-test af `visited`
- markér et stadion som besøgt i appen, og se ændringen på web
- markér et stadion som ikke besøgt i appen, og se ændringen på web
- markér et stadion som besøgt på web, og se korrekt status i appen efter normal sync
- `/`, `/my`, `/matches`, `/stadiums/[id]` og `/matches/[id]` viser samme visited-status på web
- `Min tur` viser konsistent progression mellem app og web inden for den delte model

Aktuel status:
- verificeret manuelt som fungerende begge veje
- steady-state er nu shared backend for `visited`
- sync er stabil ved app-aktivering og browserfokus, men er ikke bygget som realtime-subscription

### 6. App-only data opfører sig ærligt
- noter, reviews, fotos og weekend-plan er stadig synlige og stabile i appen
- web lover ikke, at disse data deles på tværs endnu
- produktcopy modsiger ikke den besluttede datamatrix

### 7. Go / No-Go
Go:
- alle build- og datatjek er grønne
- auth, bootstrap og delt `visited` virker i praksis på tværs af app og web
- reference-data opleves konsistente i de centrale produktflader
- app-only data forbliver stabile og bliver ikke fejlagtigt præsenteret som shared

Aktuel vurdering:
- integrationen er nu `Go med kendt begrænsning` for den delte `visited`-model
- kendt begrænsning: tværflade-sync er fokus/aktiveringsbaseret, ikke realtime
- den begrænsning er acceptabel, så længe sanity-rutinen fortsat er grøn

No-Go:
- app og web viser forskellig visited-status uden forklaring
- bootstrap overskriver eller taber brugerens forventede visited-data
- reference-data divergerer mellem fladerne
- nye integrationsændringer introducerer compile-fejl eller reel regressionswarning
- produktcopy lover deling af data, som stadig er app-only

## AS2 Submission Readiness Status

### Bekræftet i projektet
- Bundle ID: `everystadium.Tribunetour`
- Projektversion: `0.1.0`
- Buildnummer: `7`
- Location permission-tekst findes:
  - `Bruges til at vise stadion tættest på din position`
- iCloud/CloudKit entitlements er koblet på app-target
- Lokale notifikationer anmodes runtime via `UNUserNotificationCenter`

### Skal afklares eller færdiggøres
- Versionsstrategi:
  - Næste planlagte submission er `0.1.0 (7)`
  - Versionslinjen er nu aligned i projekt og release-noter
- Screenshots:
  - mangler bekræftet som klar leverance
- App Store metadata:
  - app-beskrivelse, keywords, promotional text og support-URL skal bekræftes
- App Privacy i App Store Connect:
  - skal udfyldes og matches mod faktisk dataindsamling/sync
- Release sanity:
  - sidste gennemgang i Release-build på fysisk enhed anbefales før submission

### Foreløbig vurdering
- Teknisk readiness: tæt på
- Submission readiness: ikke klar endnu
- Primære blockers: App Store metadata/compliance + endeligt version bump i projektet

## AS2 Metadata Package (forslag)

### App Name
`Tribunetour`

### Subtitle
`Find kampe og følg dine stadionbesøg`

### Promotional Text
`Find kommende kampe, planlæg stadionture og hold styr på de stadions, du har besøgt.`

### Keywords
`fodbold,stadion,kampe,groundhopping,superliga,stadionbesøg,kampprogram,rejser,sport`

### Short Description Angle
Tribunetour samler kampe, stadions og din personlige progression i én enkel app.

### App Store Description (forslag)
`Tribunetour er til dig, der elsker fodbold, kampe og stadionoplevelser.

Med Tribunetour kan du:
- finde kommende kampe
- udforske stadions på kort og i lister
- markere hvilke stadions du har besøgt
- planlægge kommende stadionture
- gemme billeder og anmeldelser fra dine besøg
- følge din egen progression over tid

Appen giver dig et samlet overblik over kampprogram, stadioner og dine egne oplevelser.

Bemærk:
- Kampprogram og stadiondata leveres i denne version som indbyggede data i appen
- Sociale funktioner og ranglister er ikke en del af første offentlige version`

### Support URL
- Anbefalet URL: `https://tribunetour.dk/support`
- Minimumsindhold:
  - kort forklaring af appen
  - kontaktmail eller kontaktformular
  - kort FAQ om sync/iCloud og fejlrapportering
  - evt. henvisning til privacy policy
- Submission-blokerende hvis den mangler eller ikke virker

### Support Page Spec (`tribunetour.dk/support`)
- Sideformål:
  - give App Store-reviewer og brugere en enkel supportindgang
  - forklare de vigtigste flows uden marketingfyld
- Minimumssektioner:
  - `Om Tribunetour`
  - `Kontakt`
  - `FAQ`
  - `Privatliv`
- Foreslået indhold:
  - `Om Tribunetour`
    - kort tekst: Tribunetour hjælper dig med at finde kampe, holde styr på stadions du har besøgt og planlægge kommende stadionture
  - `Kontakt`
    - supportmail, fx `tribunetour@toudal.dk`
    - forventningsafstemning: svartid 2-5 hverdage
  - `FAQ`
    - `Hvorfor kan jeg ikke se mine data på en ny enhed?`
    - svar: personlige data synkroniseres via iCloud/CloudKit og kræver at brugeren er logget ind med iCloud
    - `Hvorfor er et kamptidspunkt forkert?`
    - svar: appen bruger indbyggede kampdata i denne version; fejl rettes via app-opdatering eller senere remote data-feed
    - `Hvordan rapporterer jeg en fejl?`
    - svar: send en kort beskrivelse, device-model, iOS-version og gerne screenshot
  - `Privatliv`
    - kort link/tekst til privacy policy
    - nævn at appen bruger lokation til afstand/nærhedsfunktioner og iCloud til personlige data
- Tekniske krav:
  - siden skal virke uden login
  - siden skal være mobilvenlig
  - URL må ikke redirecte rundt i flere led
  - siden skal være offentlig og stabil før submission

### App Privacy – foreløbig afklaring
- Lokation bruges til funktioner som `tættest på mig`
- Brugerindhold omfatter mindst:
  - stadionbesøg
  - noter og anmeldelser
  - billeder/captions
  - plan-data
- Appen bruger CloudKit private database til personlige data
- Apple-dokumentation understreger, at private CloudKit-data tilhører brugeren og ligger i brugerens private database
- Ingen tydelige tegn på tredjeparts analytics eller ad tracking i nuværende app
- Praktisk udfyldelse i App Store Connect bør valideres manuelt mod Apples privacy-definitioner, især for:
  - data der kun synkroniseres via brugerens egen iCloud/CloudKit
  - lokation der bruges i appen, men ikke nødvendigvis deles med udvikleren

### App Privacy – arbejdshypotese før udfyldelse
- Sandsynligvis relevant at gennemgå kategorier for:
  - `Location`
  - `User Content`
- Sandsynligvis ikke relevant:
  - `Tracking`
  - tredjeparts analytics / advertising data
- Kræver manuel bekræftelse i App Store Connect før submission

## Screenshot Plan (App Store)

### Anbefalet rækkefølge
1. **Stadions-overblik**
   - Vis liste + kort + tydelig søgning
   - Formål: forklare at appen giver overblik over stadioner
2. **Kampe**
   - Vis kommende kampe med filtre/chips
   - Formål: vise at appen hjælper med at finde næste kamp
3. **Plan**
   - Vis intervalvalg og udvalgte kampe i planen
   - Formål: understrege planlægningsværdien
4. **Stadiondetalje**
   - Vis besøgt-status, kommende kampe, billeder eller review
   - Formål: vise dybde i stadionoplevelsen
5. **Min tur**
   - Vis progression, statistik og achievements
   - Formål: vise den personlige tracking-del

### Praktiske screenshot-noter
- Brug et konsistent datasæt med 3-5 besøgte stadions, så UI ser levende ud
- Undgå debug-elementer, interne tools og testknapper
- Sørg for at mindst ét screenshot viser billeder/reviews
- Sørg for at mindst ét screenshot viser planlægningsflowet
- Undgå for meget tekst i selve UI; App Store-teksten skal bære forklaringen

### Caption-retning pr. screenshot
1. `Find stadioner og få overblik`
2. `Se kommende kampe`
3. `Planlæg din næste stadiontur`
4. `Gem billeder og anmeldelser`
5. `Følg din progression`

## Shot-by-Shot Guide

### Shot 1 – Stadions-overblik
- Åbn `Stadions`
- Brug listevisning med synligt søgefelt
- Sørg for at flere klubber er synlige, og at mindst én er markeret som besøgt
- Hvis kortet ser godt ud i toppen, må det gerne være med
- Formål:
  - vise overblik, søgning og visited-status i ét billede

### Shot 2 – Kampe
- Åbn `Kampe`
- Brug filter hvor der stadig er 4-6 kommende kampe synlige
- Vælg gerne `Kun stadions jeg ikke har besøgt`
- Vis chips/tidsfilter tydeligt
- Undgå tom states
- Formål:
  - vise at appen hjælper med at finde relevante kommende kampe

### Shot 3 – Plan
- Åbn `Plan`
- Brug et interval med flere udvalgte kampe
- Sørg for at 2-4 kampe er markeret i planen
- Intervallet skal være let aflæseligt øverst
- Formål:
  - vise planlægningsværdien og at man kan bygge sin egen tur

### Shot 4 – Stadiondetalje
- Åbn en stadiondetalje for et besøgt stadion
- Sørg for at følgende gerne er synligt samtidig:
  - besøgt-status
  - besøgsdato
  - mindst ét billede eller caption
  - evt. en kort note eller review-indhold
- Undgå at skærmen ser overfyldt ud
- Formål:
  - vise at appen ikke kun tracker, men også gemmer oplevelsen

### Shot 5 – Min tur
- Åbn `Min tur`
- Sørg for at progression, statistik og achievements ser levende ud
- Brug et datasæt hvor der er tydelig fremdrift
- Undgå debug/toasts i screenshot
- Formål:
  - vise den personlige progression og langsigtede værdi i appen

### Praktisk optagelsesflow
1. Brug samme device-type til alle screenshots
2. Brug samme sprog og samme datasæt hele vejen
3. Aktivér ikke debug-features eller interne tools under optagelse
4. Tag flere varianter af hvert shot og vælg den roligste version
5. Prioritér læsbarhed over at vise “alt”

### Klargøring af data før optagelse
- Hav 3-5 besøgte stadions
- Hav mindst 1-2 stadions med billeder
- Hav mindst 1 stadion med review/noter
- Hav et plan-interval med udvalgte kampe
- Hav nok kommende kampe i kamplisten til at den ser aktiv ud

## TestFlight Package (copy/paste)

### What's New in This Build (0.1.0 build 7)
- Nyt: Stadionbilleder med galleri, billedtekster og sync
- Nyt: Stadionanmeldelser med scores, noter og opsummering
- Nyt: Achievements/progression med unlock-feedback
- Forbedret stabilitet i CloudKit-sync og data-persistence

### What to Test
- Tilføj billeder og billedtekster, og verificér at de bevares efter relaunch/reinstall
- Opret og redigér en stadionanmeldelse, og verificér at data bevares
- Test achievements: unlock, reset og korrekt feedback-visning
- Verificér at appen føles stabil i daglig brug (Stadions, Kampe, Plan, Min tur)

### Pre-Upload Check (owner)
- Build + tests grønne i Xcode
- CloudKit schema er publiceret i korrekt miljø
- Changelog og backlog er opdateret
- Verificér at kickoff-tider efter sommertid vises korrekt (Europe/Copenhagen)
