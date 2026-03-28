# Visited Shared Model

## Formål
Dette dokument definerer den første fælles brugerdata-model, som skal kunne bruges på tværs af web og app.

Fokus er bevidst smalt:
- `visited`
- `visitedDate`
- metadata nok til sync og konfliktløsning

Det er den første fælles model, fordi den:
- er central for produktoplevelsen
- er lavere risiko end fotos, reviews og planer
- unlocker reel paritet i `Stadions`, `Kampe` og `Min tur`

## Scope

### I scope
- stadion/club reference
- besøgt ja/nej
- besøgsdato
- tidsstempler til sync
- brugeridentitet

### Ikke i scope endnu
- noter
- reviews
- billeder
- plans/weekend plans
- achievements

## Domæneintention
En bruger skal have én entydig besøgsstatus pr. stadion/klub.

Det betyder:
- én bruger
- ét stadion/klub-id
- én visited record

## Foreslået record

```json
{
  "userId": "uuid-or-auth-sub",
  "clubId": "string",
  "visited": true,
  "visitedDate": "2025-08-17T00:00:00Z",
  "createdAt": "2025-08-17T18:42:11Z",
  "updatedAt": "2025-08-17T18:42:11Z",
  "source": "web"
}
```

## Felter

### `userId`
- entydig brugeridentitet fra fælles auth-lag
- required

### `clubId`
- stabil reference til stadium/club-modellen
- required
- skal matche reference-data på tværs af app og web

### `visited`
- boolean
- required
- primær sandhed for om stedet er besøgt

### `visitedDate`
- optional dato/tid
- hvis brugeren ikke angiver dato, kan feltet være `null`
- hvis dato kun er dag-nøjagtig i UI, må backend stadig gemme som ISO timestamp

### `createdAt`
- record-oprettelsestid
- required

### `updatedAt`
- seneste mutationstid
- required

### `source`
- optional, men anbefalet
- fx `ios`, `web`, `migration`
- bruges til drift/debug, ikke som brugerlogik

## Unik nøgle
Der skal kun findes én visited-record pr.:
- `userId`
- `clubId`

Det betyder:
- unik constraint på `(userId, clubId)`

## Produktregler

### Regel 1: visited er stærkere end ikke-visited
Hvis en record først er sat til besøgt, er det en væsentlig brugerhandling.

Vi bør derfor være varsomme med automatisk at overskrive `true` med `false`.

### Regel 2: visitedDate er valgfri
Brugeren må godt kunne markere et sted som besøgt uden at vælge dato.

### Regel 3: clubId er broen til alt andet
Visited-modellen må ikke opfinde sin egen stadium-identitet.
Den skal referere direkte til reference-data.

## API-former

### Read
Vi skal kunne læse:
- alle brugerens visited records
- én visited status pr. clubId

Typiske outputs:
- liste til `Min tur`
- lookup-map til `Stadions`
- lookup-map til `Kampe`

### Write
Vi skal kunne:
- markere som besøgt
- fjerne besøgt-status
- opdatere visitedDate

## Konfliktretning
Den nuværende app bruger følgende principper:
- `visited`: true wins
- `visitedDate`: earliest non-nil date wins
- `updatedAt`: newest timestamp bruges til øvrige felter

Den retning bør vi holde fast i som udgangspunkt for shared model.

### Anbefalet konfliktpolitik v1
- `visited`: `true` vinder over `false`
- `visitedDate`: tidligste ikke-null dato vinder
- `updatedAt`: nyeste mutationstid gemmes som record timestamp

Begrundelse:
- matcher appens nuværende merge-logik
- reducerer risiko for at miste et registreret besøg

## Mapping fra nuværende app-model
Nuværende app-model i `VisitedStore`/CloudKit indeholder mere end shared model:
- `visited`
- `visitedDate`
- `notes`
- `review`
- `photoFileNames`
- `photoMetadata`
- `updatedAt`

Første fælles mapping bør være:

### App -> Shared
- `clubId` -> `clubId`
- `visited` -> `visited`
- `visitedDate` -> `visitedDate`
- `updatedAt` -> `updatedAt`

### Ignoreres i første iteration
- `notes`
- `review`
- `photos`

## UI-konsekvenser

### Stadions
Skal kunne vise:
- besøgt
- ikke besøgt
- filtrering på status

### Kampe
Skal kunne vise:
- om stadion er besøgt
- evt. filter på kun ikke-besøgte venues

### Min tur
Skal kunne vise:
- samlet antal besøgte
- antal tilbage
- liste over besøgte steder

## Overgangsstrategi

### Fase 1
Dokumentér shared model og brug den som kontrakt for web.

### Fase 2
Lad web skrive/læse visited ud fra fælles auth-retning.

### Fase 3
Afklar hvordan appens eksisterende CloudKit-data:
- migreres
- spejles
- eller sameksisterer midlertidigt

## Beslutninger
- første fælles brugerdata er `visited`
- shared model holdes minimal
- appens eksisterende rige model reduceres til shared subset i første omgang
- konfliktregler skal ligge tæt på appens nuværende merge-regler

## Næste arbejde
1. beskrive backend-contract for visited reads/writes
2. beslutte om appen senere skal:
   - migrere
   - spejle
   - eller køre hybrid-model i en periode
3. bruge modellen direkte i næste web-iteration

Se `VISITED_BACKEND_CONTRACT.md` for read/write-kontrakten.
