# Photos Backend Contract

## Formål
Dette dokument beskriver den første konkrete backend- og storage-kontrakt for shared `photos`.

Målet er:
- at app og web kan læse samme foto-metadata
- at binære filer kan ligge i shared storage uden at gøre metadata-reads tunge
- at foto-upload, caption og delete kan bygges som ét fælles spor

## Scope
Kontrakten gælder kun for brugerens egne stadionfotos.

Ikke i scope:
- offentlige fotogallerier
- community-fotos
- billedredigering
- billedmoderation
- thumbnail-pipelines

## Shared model
Se også:
- `PHOTOS_SHARED_MODEL.md`

Metadata-record:

```json
{
  "userId": "uuid-or-auth-sub",
  "clubId": "brondby-if",
  "fileName": "brondby-if_1234.jpg",
  "caption": "Aftenlys over Sydsiden",
  "createdAt": "2026-03-30T12:00:00Z",
  "updatedAt": "2026-03-30T12:05:00Z",
  "source": "web"
}
```

Storage-path:

```text
stadium-photos/{userId}/{clubId}/{fileName}
```

## Auth-krav

### Princip
Alle foto-requests er brugerbundne.

Det betyder:
- brugeren skal være autentificeret
- backend må ikke stole på vilkårlig `userId` fra klienten
- reads og writes skal være scoped til auth-brugeren

## Read-kontrakter

### 1. List all photos for current user

#### Request
`GET /photos`

#### Auth
Required

#### Response
```json
{
  "items": [
    {
      "clubId": "brondby-if",
      "fileName": "brondby-if_1234.jpg",
      "caption": "Aftenlys over Sydsiden",
      "createdAt": "2026-03-30T12:00:00Z",
      "updatedAt": "2026-03-30T12:05:00Z",
      "source": "web",
      "signedUrl": "https://..."
    }
  ]
}
```

#### Regler
- metadata skal kunne læses uden at downloade filbinæret
- `signedUrl` må gerne være kortlivet
- sortering anbefales som nyeste `createdAt` først inden for hvert stadion

### 2. Read one stadium's photos for current user

#### Request
`GET /photos/:clubId`

#### Auth
Required

#### Response
```json
{
  "clubId": "brondby-if",
  "items": [
    {
      "fileName": "brondby-if_1234.jpg",
      "caption": "Aftenlys over Sydsiden",
      "createdAt": "2026-03-30T12:00:00Z",
      "updatedAt": "2026-03-30T12:05:00Z",
      "source": "web",
      "signedUrl": "https://..."
    }
  ]
}
```

## Write-kontrakter

### 1. Upload photo

#### Request
`POST /photos/:clubId`

#### Auth
Required

#### Multipart fields
- `file`
- optional `caption`
- optional `source`

#### Resultat
1. fil uploades til private/shared bucket
2. metadata upsertes i `photos`
3. respons returnerer metadata + ny signed URL

#### Success response
```json
{
  "clubId": "brondby-if",
  "fileName": "brondby-if_1234.jpg",
  "caption": "",
  "createdAt": "2026-03-30T12:00:00Z",
  "updatedAt": "2026-03-30T12:00:00Z",
  "source": "web",
  "signedUrl": "https://..."
}
```

### 2. Update caption

#### Request
`PUT /photos/:clubId/:fileName`

#### Auth
Required

#### Request body
```json
{
  "caption": "Ny billedtekst",
  "updatedAt": "2026-03-30T12:05:00Z",
  "source": "web"
}
```

#### Regler
- `caption` må gerne være tom streng
- filbinæret ændres ikke
- `updatedAt` styrer konfliktretning

### 3. Delete photo

#### Request
`DELETE /photos/:clubId/:fileName`

#### Auth
Required

#### Regler
- metadata-record slettes
- binær fil slettes fra storage
- operationen er ikke kun “skjul lokalt”

## Konfliktretning

V1-regel:
- caption og metadata følger nyeste `updatedAt`
- delete vinder over ældre caption-opdateringer
- binær fil antages immutable i v1

Det betyder:
- hvis et foto skal ændres visuelt, er det et nyt upload i v1
- eksisterende `fileName` er identiteten

## V1-database- og storage-retning

Anbefalet første løsning:
- tabel: `photos`
- unik nøgle: `(user_id, club_id, file_name)`
- private bucket: `stadium-photos`

Felter:
- `user_id`
- `club_id`
- `file_name`
- `caption`
- `created_at`
- `updated_at`
- `source`

## Næste arbejde

1. oprette `photos` tabel + bucket i Supabase
2. lægge første repository/hook på web
3. åbne første webflow for upload, caption og delete
4. koble appens foto-boundary på samme shared retning
