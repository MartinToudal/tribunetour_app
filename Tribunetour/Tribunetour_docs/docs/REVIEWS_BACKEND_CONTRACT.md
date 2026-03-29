# Reviews Backend Contract

## Formål
Dette dokument beskriver den første konkrete backend-kontrakt for shared `reviews`.

Det er ikke en fuld backend-spec for alle richer brugerdata.
Det er en pragmatisk kontrakt for:
- reads
- writes
- auth
- validering
- konfliktretning

Målet er, at app og web kan bygges mod samme reviewmodel uden at opfinde en separat webvariant.

## Scope
Kontrakten gælder kun for shared stadionreviews.

Ikke i scope:
- billeder eller attachments
- flere reviews pr. stadion
- offentlige eller delte community-reviews
- review-likes, kommentarer eller moderation

## Entitet
Se også:
- `REVIEWS_SHARED_MODEL.md`

Grundrecord:

```json
{
  "userId": "uuid-or-auth-sub",
  "clubId": "string",
  "matchLabel": "FCK - Brondby 2-1",
  "scores": {
    "atmosphereSound": 5,
    "sightlinesSeats": 4,
    "aestheticsHistory": 4,
    "foodDrinkQuality": 3,
    "foodDrinkPrice": 2,
    "valueForMoney": 4,
    "accessTransport": 5,
    "facilities": 4,
    "matchdayOperations": 4,
    "familyFriendliness": 3,
    "awayFanConditions": 4
  },
  "categoryNotes": {
    "atmosphereSound": "Virkelig høj lyd bag målet",
    "foodDrinkPrice": "Ret dyr øl"
  },
  "summary": "Stærk stemning og flot stadionoplevelse.",
  "tags": "god stemning,dyr øl",
  "createdAt": "2026-03-29T18:42:11Z",
  "updatedAt": "2026-03-29T18:42:11Z",
  "source": "web"
}
```

## Auth-krav

### Princip
Alle review-requests er brugerbundne.

Det betyder:
- brugeren skal være autentificeret
- backend må ikke acceptere vilkårlige `userId` fra klienten som sandhed
- `userId` skal komme fra auth-konteksten

## Read-kontrakter

### 1. List all reviews for current user

#### Request
`GET /reviews`

#### Auth
Required

#### Response
```json
{
  "items": [
    {
      "clubId": "brondby-if",
      "matchLabel": "Brondby - FCK 1-0",
      "scores": {
        "atmosphereSound": 5,
        "facilities": 3
      },
      "categoryNotes": {
        "atmosphereSound": "Stærk lyd hele kampen"
      },
      "summary": "Meget stærk hjemmebaneoplevelse.",
      "tags": "hjemmebane,stemning",
      "createdAt": "2026-03-29T18:42:11Z",
      "updatedAt": "2026-03-29T18:42:11Z",
      "source": "web"
    }
  ]
}
```

### 2. Read one review for current user

#### Request
`GET /reviews/:clubId`

#### Auth
Required

#### Success response
```json
{
  "clubId": "brondby-if",
  "matchLabel": "Brondby - FCK 1-0",
  "scores": {
    "atmosphereSound": 5
  },
  "categoryNotes": {},
  "summary": "Meget stærk hjemmebaneoplevelse.",
  "tags": "hjemmebane,stemning",
  "createdAt": "2026-03-29T18:42:11Z",
  "updatedAt": "2026-03-29T18:42:11Z",
  "source": "web"
}
```

#### Not found
Anbefaling:
- brug `404` for fravær af record

## Write-kontrakter

### 1. Upsert review

#### Request
`PUT /reviews/:clubId`

#### Auth
Required

#### Request body
```json
{
  "matchLabel": "Brondby - FCK 1-0",
  "scores": {
    "atmosphereSound": 5,
    "facilities": 3
  },
  "categoryNotes": {
    "atmosphereSound": "Stærk lyd hele kampen"
  },
  "summary": "Meget stærk hjemmebaneoplevelse.",
  "tags": "hjemmebane,stemning",
  "updatedAt": "2026-03-29T18:42:11Z",
  "source": "web"
}
```

#### Regler
- `clubId` kommer fra path
- payload følger samme reviewfelter som appens `StadiumReview`
- `source` er optional, men anbefalet
- tomme strenge er gyldige
- partial `scores` og `categoryNotes` er gyldige

#### Success response
```json
{
  "clubId": "brondby-if",
  "matchLabel": "Brondby - FCK 1-0",
  "scores": {
    "atmosphereSound": 5,
    "facilities": 3
  },
  "categoryNotes": {
    "atmosphereSound": "Stærk lyd hele kampen"
  },
  "summary": "Meget stærk hjemmebaneoplevelse.",
  "tags": "hjemmebane,stemning",
  "createdAt": "2026-03-29T18:42:11Z",
  "updatedAt": "2026-03-29T18:42:11Z",
  "source": "web"
}
```

### 2. Ryd reviewindhold

V1-anbefaling:
- brug samme `PUT /reviews/:clubId`
- send tomme felter og tomme objekter

Det betyder:
- review-recorden kan fortsat eksistere som record
- klienten kan også vælge at fortolke et helt tomt review som “ingen meningsfuld anmeldelse”
- backend må senere vælge at slette tomme records internt, men klientkontrakten skal være stabil

## Konfliktretning

V1-regel:
- nyeste `updatedAt` vinder hele review-recorden
- hvis `updatedAt` er ens, vinder reviewet med flest udfyldte felter
- hvis begge er lige fyldige, vinder længste `summary`

Det matcher den delte reviewmodel og undgår mærkelige feltblandinger mellem app og web.

## V1-database-retning

Den enkleste første backend-retning er:
- tabel: `reviews`
- unik nøgle: `(user_id, club_id)`
- felter:
  - `user_id`
  - `club_id`
  - `match_label`
  - `scores`
  - `category_notes`
  - `summary`
  - `tags`
  - `created_at`
  - `updated_at`
  - `source`

Anbefalet SQL-repræsentation:
- `scores` som `jsonb`
- `category_notes` som `jsonb`

Det holder modellen tæt på appens eksisterende struktur uden at splitte den op i mange relationstabeller i første iteration.

## Næste arbejde

1. etablere første repository-lag for reviews
2. koble appens nye review-boundary på samme kontraktretning
3. vise ét første review-flow i app og web
