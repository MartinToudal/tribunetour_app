# Notes Shared Model

## Formål
Dette dokument definerer den første fælles model for stadionnoter på tværs af app og web.

Målet er:
- at gøre `notes` til næste shared dataområde efter `visited`
- at holde modellen smal og kompatibel med den eksisterende app
- at undgå at blande reviews, fotos og planer ind i samme kontrakt

## Scope

### I scope
- én note pr. bruger pr. `clubId`
- noteindhold som fri tekst
- tidsstempler til konfliktløsning
- auth-bundet ejerskab

### Ikke i scope endnu
- review-noter pr. kategori
- rich text
- attachments eller billeder i noter
- delte/offentlige noter
- versionshistorik

## Domæneintention
En bruger skal kunne gemme en personlig note til et stadion.

Det betyder:
- én bruger
- ét `clubId`
- én note-record

Der er ikke behov for flere note-objekter pr. stadion i første version.

## Foreslået record

```json
{
  "userId": "uuid-or-auth-sub",
  "clubId": "string",
  "note": "Fri tekst skrevet af brugeren",
  "createdAt": "2026-03-28T18:42:11Z",
  "updatedAt": "2026-03-28T18:42:11Z",
  "source": "ios"
}
```

## Felter

### `userId`
- entydig brugeridentitet fra auth-laget
- required
- backend skal tage den fra auth-konteksten, ikke fra klientens påstand

### `clubId`
- stabil reference til stadium/club-modellen
- required
- skal bruge samme ID-familie som `visited`

### `note`
- noteindhold som fri tekst
- required i write-kontrakten, men må godt være tom streng
- tom streng betyder i praksis “ingen note”

### `createdAt`
- oprettelsestid for note-record
- required

### `updatedAt`
- seneste mutationstid
- required
- bruges som primær konfliktretning

### `source`
- optional, men anbefalet
- fx `ios` eller `web`
- bruges til drift og debug, ikke produktlogik

## Unik nøgle
Der skal kun findes én note-record pr.:
- `userId`
- `clubId`

Det betyder:
- unik constraint på `(userId, clubId)`

## Produktregler

### Regel 1: Notes er personlige
En note er brugerens egen tekst til eget brug.
Den er ikke en social eller offentlig tekst.

### Regel 2: Notes er uafhængige af `visited`
En note må gerne eksistere, selv hvis `visited = false`.

Det matcher appens nuværende model, hvor:
- `setNotes()` kan oprette eller opdatere noter uden at ændre besøgsstatus
- noteindhold derfor ikke skal tvinges bag en visited-handling

### Regel 3: Tom note er gyldig som nulstilling
Hvis brugeren sletter noteindholdet, skal systemet kunne ende i en tom note-tilstand uden tvetydighed.

V1-anbefaling:
- klienten skriver `note = ""`
- backend må gerne gemme recorden som tom streng eller vælge at rydde recorden internt
- klientkontrakten skal stadig opføre sig som om resultatet er “ingen note”

## Konfliktretning

Den eksisterende appmodel peger allerede på en enkel konfliktretning:
- nyeste `updatedAt` vinder for `notes`

Det bør vi holde fast i som v1-regel.

### Anbefalet konfliktpolitik v1
- hvis to noter konkurrerer, vinder noten med nyeste `updatedAt`
- hvis `updatedAt` er ens, vinder længste ikke-tomme note
- tom note må godt overskrive tidligere note, hvis den er den nyeste brugerhandling

Begrundelse:
- det matcher appens nuværende `setNotes()`- og merge-tænkning rimeligt tæt
- det gør note-redigering lettere at forstå end en “true wins”-regel som på `visited`
- det gør sletning af noteindhold til en reel handling i stedet for et særtilfælde

## Mapping fra nuværende appmodel

Nuværende appmodel i `VisitedStore.Record` indeholder:
- `visited`
- `visitedDate`
- `notes`
- `review`
- `photoFileNames`
- `photoMetadata`
- `updatedAt`

Første shared mapping for notes bør være:

### App -> Shared notes
- `clubId` -> `clubId`
- `notes` -> `note`
- `updatedAt` -> `updatedAt`

### Ignoreres i første notes-iteration
- `visited`
- `visitedDate`
- `review`
- `photos`

Det er vigtigt, at `notes` ikke genbruger review-noter eller anden rig struktur i første version.

## UI-konsekvenser

### App
- eksisterende note-felt på stadiondetaljen kan være første note-entrypoint
- brugeren skal ikke mærke en ny datamodel, kun at noten senere kan deles

### Web
- ét enkelt note-entrypoint er nok i første iteration
- anbefalet første sted er stadiondetaljen eller `Min tur`, ikke alle flader samtidig

## Næste arbejde

1. beskrive backend/read-write-kontrakten for notes
2. lave en tydelig app-boundary mellem lokal note-model og shared note-model
3. derefter implementere ét bevidst note-flow i app og web

Se `NOTES_BACKEND_CONTRACT.md` for første read/write-kontrakt.
