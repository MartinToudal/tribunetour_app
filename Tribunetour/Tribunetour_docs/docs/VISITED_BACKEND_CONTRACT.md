# Visited Backend Contract

## Formål
Dette dokument beskriver den første konkrete backend-kontrakt for shared `visited`-data.

Det er ikke en endelig implementeringsspec for hele backend-stakken.
Det er en pragmatisk kontrakt for:
- reads
- writes
- identitet
- validering
- konfliktretning

Målet er, at web kan bygges mere disciplineret nu, og at appen senere kan kobles på samme kontrakt.

## Scope
Kontrakten gælder kun for shared `visited`-model.

Ikke i scope:
- notes
- reviews
- photos
- plans
- achievements

## Entitet
Se også:
- `VISITED_SHARED_MODEL.md`

Grundrecord:

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

## Auth-krav

### Princip
Alle visited-requests er brugerbundne.

Det betyder:
- brugeren skal være autentificeret
- backend må ikke acceptere vilkårlige `userId` fra klienten som sandhed
- `userId` skal komme fra auth-konteksten

### Klientregel
Klienten må gerne sende et felt svarende til `userId` internt, men backend skal ignorere det som autoritativt input og bruge den autentificerede bruger.

## Read-kontrakter

### 1. List all visited records for current user

#### Formål
Bruges til:
- `Min tur`
- lookup maps til `Stadions`
- lookup maps til `Kampe`

#### Request
`GET /visited`

#### Auth
Required

#### Response
```json
{
  "items": [
    {
      "clubId": "brondby-if",
      "visited": true,
      "visitedDate": "2024-05-12T00:00:00Z",
      "createdAt": "2024-05-12T18:10:00Z",
      "updatedAt": "2024-05-12T18:10:00Z",
      "source": "web"
    }
  ]
}
```

### 2. Read one visited record for current user

#### Request
`GET /visited/:clubId`

#### Auth
Required

#### Success response
```json
{
  "clubId": "brondby-if",
  "visited": true,
  "visitedDate": "2024-05-12T00:00:00Z",
  "createdAt": "2024-05-12T18:10:00Z",
  "updatedAt": "2024-05-12T18:10:00Z",
  "source": "web"
}
```

#### Not found response
`404` eller `200` med `null` payload er begge mulige, men vi bør vælge én konsekvent form.

Anbefaling:
- brug `404` for fravær af record

## Write-kontrakter

### 1. Upsert visited state

#### Formål
Bruges når bruger:
- markerer et stadion som besøgt
- fjerner besøgt-status
- ændrer visitedDate

#### Request
`PUT /visited/:clubId`

#### Auth
Required

#### Request body
```json
{
  "visited": true,
  "visitedDate": "2025-08-17T00:00:00Z",
  "source": "web"
}
```

#### Regler
- `clubId` kommer fra path
- `visited` er required
- `visitedDate` er optional
- `source` er optional, men anbefalet

#### Success response
```json
{
  "clubId": "brondby-if",
  "visited": true,
  "visitedDate": "2025-08-17T00:00:00Z",
  "createdAt": "2025-08-17T18:42:11Z",
  "updatedAt": "2025-08-17T18:42:11Z",
  "source": "web"
}
```

### 2. Delete visited record

Der er to mulige modeller:

#### Model A: hård delete
`DELETE /visited/:clubId`

Fordel:
- enkel backend-model

Ulempe:
- sværere at bevare historik og konfliktinformation

#### Model B: soft update til `visited = false`
`PUT /visited/:clubId` med:

```json
{
  "visited": false,
  "visitedDate": null,
  "source": "web"
}
```

Anbefaling:
- brug Model B i første iteration

Begrundelse:
- tættere på appens eksisterende record-tænkning
- enklere ved senere konfliktløsning
- undgår forskel på “ingen record” og “record nulstillet” som driftsteknisk specialtilfælde

## Validering

### `clubId`
- skal findes i reference-data
- backend skal afvise ukendte IDs

### `visited`
- skal være boolean

### `visitedDate`
- må være `null`
- hvis sat, skal den være gyldig ISO timestamp

### `source`
- hvis sendt, skal den komme fra kendt enum eller kendt strengsæt

Anbefalet sæt:
- `ios`
- `web`
- `migration`

## Konfliktretning

### Minimumskrav
Hvis flere klienter skriver til samme `(userId, clubId)`, skal vi have forudsigelig adfærd.

### Anbefalet v1-politik
- `visited = true` vinder over `false`
- `visitedDate`: tidligste ikke-null dato vinder
- `updatedAt`: nyeste mutationstid gemmes som record-opdateringstid

### Praktisk konsekvens
Backend må ikke bare bruge “last write wins” ukritisk på hele recorden, da det kan fjerne et registreret besøg.

## Response-shape
Konsekvent response-shape gør UI-arbejdet enklere.

Anbefaling:
- returnér altid den canonical record efter write
- returnér timestamps fra backend, ikke klientens antagelser

## UI-kontrakt

Web kan stole på:
- `GET /visited` giver hele brugerens visited-grundlag
- `PUT /visited/:clubId` returnerer den nye canonical status
- `visited` + `visitedDate` er nok til første iteration af:
  - `Stadions`
  - `Kampe`
  - `Min tur`

## Drift og logging
Backend bør logge:
- auth user
- `clubId`
- write source
- outcome

Men:
- ingen unødigt følsomme payloads i offentlige logs

## Anbefalet implementeringsretning
Hvis vi bruger en klassisk auth/backend-stack, bør backend:
- læse brugeridentitet fra session/JWT
- have unik constraint på `(userId, clubId)`
- returnere canonical record efter write

Det er nok til at starte.

## Bevidst udskudt
Dette dokument låser ikke:
- RPC vs REST
- præcis tabelform
- realtime subscriptions
- migrationsjob fra CloudKit

Det låser kun klientkontrakten og reglerne.

## Næste arbejde
1. omsætte kontrakten til webens visited-state og login-gating
2. definere hvordan appen senere kan mappes ind i samme kontrakt
3. vælge konkret backend-repræsentation, når vi er klar til det
