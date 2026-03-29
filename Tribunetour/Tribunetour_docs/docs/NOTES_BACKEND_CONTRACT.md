# Notes Backend Contract

## Formål
Dette dokument beskriver den første konkrete backend-kontrakt for shared `notes`.

Det er ikke en fuld backend-spec for alle richer brugerdata.
Det er en pragmatisk kontrakt for:
- reads
- writes
- auth
- validering
- konfliktretning

Målet er, at app og web kan bygges mod samme note-model uden at blande reviews, fotos og planer ind i første iteration.

## Scope
Kontrakten gælder kun for shared stadionnoter.

Ikke i scope:
- review-noter
- billeder
- weekend-plan
- offentlige eller delte noter mellem brugere

## Entitet
Se også:
- `NOTES_SHARED_MODEL.md`

Grundrecord:

```json
{
  "userId": "uuid-or-auth-sub",
  "clubId": "string",
  "note": "Fri tekst skrevet af brugeren",
  "createdAt": "2026-03-28T18:42:11Z",
  "updatedAt": "2026-03-28T18:42:11Z",
  "source": "web"
}
```

## Auth-krav

### Princip
Alle note-requests er brugerbundne.

Det betyder:
- brugeren skal være autentificeret
- backend må ikke acceptere vilkårlige `userId` fra klienten som sandhed
- `userId` skal komme fra auth-konteksten

## Read-kontrakter

### 1. List all notes for current user

#### Request
`GET /notes`

#### Auth
Required

#### Response
```json
{
  "items": [
    {
      "clubId": "brondby-if",
      "note": "God stemning bag målet.",
      "createdAt": "2026-03-28T18:42:11Z",
      "updatedAt": "2026-03-28T18:42:11Z",
      "source": "web"
    }
  ]
}
```

### 2. Read one note for current user

#### Request
`GET /notes/:clubId`

#### Auth
Required

#### Success response
```json
{
  "clubId": "brondby-if",
  "note": "God stemning bag målet.",
  "createdAt": "2026-03-28T18:42:11Z",
  "updatedAt": "2026-03-28T18:42:11Z",
  "source": "web"
}
```

#### Not found
Anbefaling:
- brug `404` for fravær af record

## Write-kontrakter

### 1. Upsert note

#### Request
`PUT /notes/:clubId`

#### Auth
Required

#### Request body
```json
{
  "note": "Fri tekst skrevet af brugeren",
  "source": "web"
}
```

#### Regler
- `clubId` kommer fra path
- `note` er required i klientkontrakten, men må godt være tom streng
- `source` er optional, men anbefalet

#### Success response
```json
{
  "clubId": "brondby-if",
  "note": "Fri tekst skrevet af brugeren",
  "createdAt": "2026-03-28T18:42:11Z",
  "updatedAt": "2026-03-28T18:42:11Z",
  "source": "web"
}
```

### 2. Slet noteindhold

V1-anbefaling:
- brug samme `PUT /notes/:clubId`
- send `note: ""`

Det betyder:
- tom note er en gyldig klienthandling
- backend må gerne gemme tom streng eller rydde recorden internt
- klienten skal stadig læse resultatet som “ingen note”

## Konfliktretning

V1-regel:
- nyeste `updatedAt` vinder
- hvis `updatedAt` er ens, vinder længste ikke-tomme note
- tom note må godt vinde, hvis den repræsenterer nyeste brugerhandling

Det matcher appens eksisterende retning bedre end en mere kompleks merge-model.

## V1-database-retning

Den enkleste første backend-retning er:
- tabel: `notes`
- unik nøgle: `(user_id, club_id)`
- felter:
  - `user_id`
  - `club_id`
  - `note`
  - `created_at`
  - `updated_at`
  - `source`

Det er bevidst parallelt til `visited`, så notes kan bygges med samme repository-tænkning på web og senere samme adaptertænkning i appen.

## Næste arbejde

1. etablere første repository-lag for notes
2. koble appens nye notes-boundary på samme kontraktretning
3. vise ét første note-flow i app og web

Se `NOTES_SUPABASE_SQL.md` for konkret tabel-, grant- og policy-setup i Supabase.
