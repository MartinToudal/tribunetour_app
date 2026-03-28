# Reference Data Contract

## Formål
Dette dokument fastlægger kontrakten for reference-data i Tribunetour.

Målet er at sikre, at:
- kampprogrammet kan opdateres undervejs
- web og app ikke falder fra hinanden midt i integrationsarbejdet
- brugerdata som `visited` ikke brydes af reference-data-opdateringer

## Kerneprincip
Reference-data og brugerdata er to forskellige lag.

### Reference-data
Reference-data er:
- stadions
- klubber
- ligaer
- fixtures / kampe

### Brugerdata
Brugerdata er:
- visited status
- visited date
- senere noter, planer, reviews og fotos

Kritisk regel:
- reference-data må gerne ændres ofte
- brugerdata må ikke miste sin binding som følge af reference-data-opdateringer

## Den vigtigste nøgle i hele systemet
Den stabile nøgle er `clubId`.

I praksis betyder det:
- et stadion i `stadiums` har `id`
- et fixture peger på stadion/klub via `venueClubId`
- `homeTeamId` og `awayTeamId` bruger samme ID-familie
- `visited.club_id` bruger samme ID-familie
- appens og webens detailruter bør bindes til samme ID-familie

## Canonical source lige nu

For at undgå tvivl gælder denne operationelle beslutning nu:

### Canonical source
Den canonical source for reference-data er Tribunetours kontrollerede datasæt med:
- stadions som canonical ID-lag
- fixtures som canonical kamp-lag

Det vigtige er ikke om data fysisk ligger som CSV eller JSON i alle led.
Det vigtige er, at der kun er ét autoritativt indholdssæt ad gangen.

### Distribution lige nu
I den nuværende overgang gælder:
- appens stadiondata kommer fra app-bundlet
- appens fixtures kommer fra `RemoteFixturesProvider` med lokal fallback
- web læser reference-data gennem ét samlet `referenceData`-lag
- web må gerne falde tilbage til seed-data, men kun som sekundær kilde

### Praktisk sandhedshierarki
Indtil der findes en fuldt samlet pipeline, er hierarkiet:

1. Tribunetours senest godkendte reference-datasæt
2. webens og appens genererede/distribuerede version af det datasæt
3. lokale fallback-filer, kun når primær distribution ikke er tilgængelig

Det betyder:
- lokale filer er ikke den forretningsmæssige sandhed
- lokale filer er driftsfallback
- nye opdateringer skal tænkes som opdatering af ét fælles datasæt, ikke to separate produkter

### Versionsregel
Når reference-data ændres, skal det behandles som én samlet opdatering:
- stadium- og fixture-relationer valideres først
- web og app skal pege på samme datasætversion eller samme godkendte indhold
- fallback-data skal kun bruges som sikkerhedsnet, ikke som alternativ redigeringskanal

### Konsekvens for kode
Denne beslutning betyder i praksis:
- web skal læse reference-data gennem ét loader-lag
- app og web skal begge bindes til samme ID-familie
- nye dataopdateringer må ikke laves “kun til web” eller “kun til app”, medmindre det er en bevidst nødforanstaltning

### Næste mål
Det næste ønskede slutbillede er:
- én fælles pipeline
- ét fælles output-format
- tydelig versionsmarkering
- mindst mulig manuel dobbeltopdatering

## Operativt driftsspor lige nu

Reference-data skal nu behandles som ét opdateringsflow, ikke som separate app- og webopdateringer.

### Canonical source i drift
Den operationelle canonical source er nu:
- [stadiums.csv](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/stadiums.csv)
- [fixtures.csv](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/fixtures.csv)

Det betyder:
- nye stadioner og kampopdateringer laves først her
- webens JSON-filer er genererede artefakter
- appens remote feed er et distribueret artefakt af samme datasæt

### Genererede artefakter
Når canonical source opdateres, genereres disse filer i webrepoet:
- [stadiums.json](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/data/stadiums.json)
- [fixtures.json](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/data/fixtures.json)
- [fixtures.remote.json](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/public/reference-data/fixtures.remote.json)

De genereres af:
- [generate-reference-data.mjs](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/scripts/generate-reference-data.mjs)

### Distribution
Efter generering gælder denne distribution:
- web læser reference-data via sit `referenceData`-lag
- websitet publicerer `fixtures.remote.json`
- appen udleder remote feed-URL fra [AppAuthConfiguration.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/AppAuthConfiguration.swift)
- appen læser feedet via `RemoteFixturesProvider`
- appen falder kun tilbage til lokale CSV-data, hvis remote feed ikke kan bruges

### Vercel og CI
I CI og på Vercel findes appens CSV-filer ikke direkte.

Derfor gælder:
- lokalt hos os genereres web-artefakter fra canonical CSV
- i Vercel bruges de committede web-JSON-filer som input
- Vercel genererer stadig det publicerede remote envelope, så website og app-feed forbliver konsistente med det sidst godkendte datasæt

Det betyder:
- ændringer i reference-data skal altid genereres og committes lokalt før deploy
- deploy alene er ikke stedet, hvor nye reference-data “opfindes”

## Update-flow ved reference-data-ændring

Når stadioner eller kampe ændres, er den korrekte rækkefølge nu:

1. opdatér canonical CSV i apprepoet
2. kør `npm run generate:data` i webrepoet
3. kør `npm run validate:data` i webrepoet
4. verificér at de genererede JSON-filer ser rigtige ud
5. commit appens CSV-ændring og webens genererede artefakter
6. deploy webrepoet
7. verificér live feed på `/reference-data/fixtures.remote.json`
8. verificér i appens `Interne værktøjer`, at fixtures-kilden er `remote`

### Hvad der tæller som grønt
Et reference-data-update er grønt når:
- validatoren består
- web build består
- live feed kan åbnes
- appen kan læse feedet som `remote`
- stadion- og kamp-ID’er stadig matcher `visited`-modellen

### Hvad der tæller som no-go
Et reference-data-update er ikke klar hvis:
- validatoren fejler
- `fixtures.remote.json` ikke er live efter deploy
- appen falder tilbage til `local fallback` uden bevidst grund
- relationer mellem `venueClubId`, `homeTeamId`, `awayTeamId` og stadium IDs er brudt

## Ejerskab og ansvar

For at holde flowet enkelt gælder denne arbejdsdeling:
- apprepoet ejer canonical CSV
- webrepoet ejer generering, validering og publicering af artefakter
- deploy af web er også deploy af appens remote fixtures-feed

Det betyder i praksis:
- reference-data bør tænkes som ét fælles driftsansvar
- men ændringerne lander stadig i to repos, fordi source og distribution endnu ikke fysisk bor samme sted

## Kontrakt for stadium records
Hver stadium-record skal mindst have:
- `id`
- `name`
- `team`
- `league`
- `lat`
- `lon`

### Stabilitetsregel
`id` må ikke ændres, når:
- stadionnavnet ændres
- sponsornavn ændres
- klubnavnet justeres
- koordinater forbedres
- ligaen ændres

### Eksempel
Hvis et stadion skifter navn fra:
- `Ceres Park Vejlby`
til noget andet,
så må `id = agf` stadig være den samme.

Det er afgørende, fordi både:
- fixtures
- web routes
- visited data
- senere app-integration
binder på den nøgle.

## Kontrakt for fixtures
Hvert fixture skal mindst have:
- `id`
- `kickoff`
- `round`
- `homeTeamId`
- `awayTeamId`
- `venueClubId`
- `status`

### Stabilitetsregler
#### 1. `id`
Fixture-ID bør være stabilt, så længe kampen er den samme kamp.

Det betyder:
- kickoff kan justeres uden at vi nødvendigvis skifter ID
- små tekstændringer i runde eller tv-tid bør ikke skabe nyt ID

#### 2. `venueClubId`
`venueClubId` skal altid pege på en gyldig stadium/club `id`.

Hvis denne binding brydes:
- detail-links bryder
- match cards mister stadium-kontekst
- kort, detail og visited bliver inkonsistente

#### 3. `homeTeamId` og `awayTeamId`
Skal bruge samme ID-familie som stadium/club-laget, så relationer kan udledes konsekvent.

## Hvad du gerne må opdatere frit
Følgende felter kan opdateres uden at bryde helheden, så længe ID-reglerne holdes:
- `kickoff`
- `round`
- `status`
- `homeScore`
- `awayScore`
- `league`
- `name`
- `team`
- `lat`
- `lon`

## Hvad du ikke må ændre uden migration
Disse må ikke ændres casualt:
- `stadiums.id`
- `fixtures.id` for eksisterende kamp, medmindre du bevidst skifter identitet
- `fixtures.venueClubId` til en ikke-eksisterende nøgle
- `homeTeamId` / `awayTeamId` til et andet ID-system

## Praktisk regel for din kommende app-opdatering
Hvis du skal opdatere kampprogrammet i løbet af få dage, så er det sikkert at:
- tilføje nye fixtures
- rette kickoff-tider
- rette runde-tekst
- opdatere status
- justere scores

Det er ikke sikkert at:
- omdøbe IDs
- udskifte ID-strukturen
- ændre venue-bindinger uden at kontrollere datarelationerne

## Minimum sanity checks ved fixture-opdatering
Hver gang kampprogrammet opdateres, bør du kontrollere:

1. alle `venueClubId` findes i stadiumdatasættet
2. alle `homeTeamId` findes i samme ID-familie
3. alle `awayTeamId` findes i samme ID-familie
4. der er ingen dubletter i fixture IDs
5. gamle kendte detailruter bryder ikke
6. der er ingen dubletter i stadium IDs
7. koordinater ligger inden for gyldige lat/lon-intervaller
8. `venueClubId` matcher som udgangspunkt `homeTeamId`, eller afvigelsen er bevidst kontrolleret

## Konsekvens for integrationen
Dette er den vigtigste pointe:
- vi kan godt fortsætte mod ét produkt
- samtidig med at du laver en isoleret app-opdatering
- så længe reference-data-kontrakten holdes stabil

Det betyder, at din kommende app-release ikke bør blive blokeret af det shared visited-spor vi bygger nu.

## Næste anbefalede arbejde
Når du er klar, bør vi tage et lille teknisk værktøjsspor:
- en validator for reference-data

Den validator bør mindst tjekke:
- ugyldige `venueClubId`
- manglende klub-ID-relationer
- dubletter i fixture IDs
- dubletter i stadium IDs
- tomme eller uventede league-værdier
- ugyldige koordinater
- mistænkelige fixture-relationer som `venueClubId != homeTeamId`

Det vil gøre fremtidige kampprogram-opdateringer væsentligt sikrere under integrationsarbejdet.
