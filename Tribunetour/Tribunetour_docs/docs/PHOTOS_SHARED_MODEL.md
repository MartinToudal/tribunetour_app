# Photos Shared Model

## Formål
Dette dokument fastlåser første fælles model for stadionbilleder mellem app og web.

Målet er:
- at app og web arbejder mod samme foto-identitet
- at storage og metadata kan deles uden særmodeller
- at upload/visning kan bygges på web uden at sprede appens `VisitedStore` direkte videre

## Principper
- ét foto tilhører én bruger og ét `clubId`
- fotoets binære fil og fotoets metadata behandles som to lag af samme model
- app og web skal bruge samme metadatafelter
- captions er knyttet til det enkelte foto, ikke til stadionet som helhed
- fotos er brugerdata, ikke reference-data

## Shared identitet
Et shared foto identificeres af:
- `userId`
- `clubId`
- `fileName`

`fileName` er den stabile foto-id i v1.

Det betyder:
- appens eksisterende filnavne kan genbruges
- web må ikke opfinde en separat intern foto-id-model i første version

## Shared metadata v1
Et delt foto har i v1 disse felter:

```json
{
  "userId": "uuid",
  "clubId": "brondby",
  "fileName": "brondby_1234.jpg",
  "caption": "Aftenlys over Sydsiden",
  "createdAt": "2026-03-30T12:00:00Z",
  "updatedAt": "2026-03-30T12:05:00Z",
  "source": "ios"
}
```

## Feltregler

### `userId`
- auth-brugerens id
- kræves i backendlaget

### `clubId`
- skal matche det fælles stadion-id
- samme `clubId` som i `visited`, `notes` og `reviews`

### `fileName`
- stabil nøgle for fotoet
- bruges både til metadata-record og storage-path
- må ikke omskrives mellem app og web i v1

### `caption`
- valgfri tekst
- tom streng betyder “ingen billedtekst”

### `createdAt`
- tidspunkt hvor fotoet først blev oprettet
- bruges til sortering og første-visning

### `updatedAt`
- tidspunkt for seneste metadataændring
- bruges til konfliktretning for caption og delete/update-flow

### `source`
- forventede værdier i v1:
  - `ios`
  - `web`
  - `shared`

## Storage-retning v1
V1 antager:
- én shared storage-bucket til foto-filer
- metadata lagres separat fra binær fil
- metadata kan læses uden at downloade selve billedet

Anbefalet path-retning:

```text
stadium-photos/{userId}/{clubId}/{fileName}
```

## Konfliktregel v1
Metadata følger:
- seneste `updatedAt` vinder

Delete-regel:
- sletning skal behandles som en eksplicit shared operation
- web og app må ikke bare skjule fotoet lokalt og antage, at det er færdigt

## Scope i v1
Med i scope:
- upload
- listevisning
- fullscreen-visning
- caption
- delete

Udenfor scope i v1:
- billedredigering
- favoritmarkering
- albums
- sortering ud over `createdAt`
- delte offentlige gallerier
- komprimeringsprofiler per platform

## App-boundary konsekvens
Appen skal ikke lade views kende foto-logik direkte gennem `VisitedStore`.

App-seamet i v1 er:
- `AppPhotosStore`

Det betyder:
- views læser foto-liste, caption og fil-URL via boundary'en
- foto-upload og delete går gennem boundary'en
- backend/storage kan senere flyttes bag boundary'en uden ny view-omskrivning

## Konklusion
Shared photos i v1 følger appens eksisterende foto-identitet og metadata i stedet for at opfinde en web-specifik model.

Det er samme princip, som vi endte med for `reviews`:
- én model
- én identitet
- én vej videre til shared backend
