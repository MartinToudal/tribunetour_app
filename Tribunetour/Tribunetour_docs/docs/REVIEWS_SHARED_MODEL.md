# Reviews Shared Model

## Formål
Dette dokument definerer den fælles model for stadionreviews på tværs af app og web.

Målet er:
- at gøre `reviews` til næste shared dataområde efter `notes`
- at bruge samme reviewmodel i app og web
- at undgå en separat "web-light" reviewstruktur, som senere skal mappes tilbage

## Scope

### I scope
- ét review pr. bruger pr. `clubId`
- samme reviewfelter som appens nuværende `VisitedStore.StadiumReview`
- læs/skriv på tværs af app og web
- `updatedAt` som primær konfliktretning

### Ikke i scope endnu
- attachments eller billeder
- flere reviews pr. stadion
- offentlige/sociale reviews
- delt billedmetadata som del af reviewkontrakten

## Domæneintention
En bruger skal kunne gemme ét personligt stadionreview, som kan læses og redigeres fra både app og web.

Det betyder:
- én bruger
- ét `clubId`
- én review-record

Første shared version forsøger ikke at modellere flere separate kampoplevelser pr. stadion.

## Kildemodel
Shared reviewmodellen følger appens eksisterende:
- `VisitedStore.StadiumReview`

Det betyder, at web og app skal tale samme datasprog for reviews, ikke to forskellige v1/v2-modeller.

## Foreslået record

```json
{
  "userId": "uuid-or-auth-sub",
  "clubId": "string",
  "review": {
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
    "updatedAt": "2026-03-29T18:15:00Z"
  },
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
- skal bruge samme ID-familie som `visited` og `notes`

### `review.matchLabel`
- optional streng
- samme semantik som i appen
- tom streng er gyldig

### `review.scores`
- objekt med samme kategorier som appens `VisitedStore.ReviewCategory`
- heltalsværdier fra `1` til `5`
- partial scores er tilladt, præcis som i appen

#### Fælles scorekategorier
- `atmosphereSound`
- `sightlinesSeats`
- `aestheticsHistory`
- `foodDrinkQuality`
- `foodDrinkPrice`
- `valueForMoney`
- `accessTransport`
- `facilities`
- `matchdayOperations`
- `familyFriendliness`
- `awayFanConditions`

### `review.categoryNotes`
- objekt med samme kategori-nøgler som `scores`
- hver værdi er fri tekst
- tom eller manglende tekst er gyldig

### `review.summary`
- fri tekst med brugerens samlede review
- optional
- tom streng er gyldig

### `review.tags`
- samme enkle strengmodel som appen bruger i dag
- optional
- tom streng er gyldig

### `review.updatedAt`
- seneste mutationstid for hele reviewet
- required
- bruges som primær konfliktretning

### `source`
- optional, men anbefalet
- fx `ios` eller `web`
- bruges til drift og debug, ikke produktlogik

## Unik nøgle
Der skal kun findes én review-record pr.:
- `userId`
- `clubId`

Det betyder:
- unik constraint på `(userId, clubId)`

## Produktregler

### Regel 1: Reviews er personlige i første version
Et review er brugerens eget stadionreview.
Det er ikke et offentligt community-review.

### Regel 2: Review og `visited` hænger produktmæssigt sammen
I produktet giver det mest mening, at et review knytter sig til et stadion, brugeren faktisk har været på.

V1-anbefaling:
- klienten må gerne sætte `visited = true` lokalt, når review oprettes i appen
- shared review-kontrakten afhænger dog ikke teknisk af `visited`

### Regel 3: Samme model begge steder
Web må ikke indføre en særskilt reduceret reviewmodel.

Det betyder:
- samme felter i app og web
- samme scorekategorier i app og web
- samme `categoryNotes`-struktur i app og web

### Regel 4: Tomme felter er gyldige
Et review må gerne være delvist udfyldt, så længe modellen stadig følger samme feltstruktur.

Det passer bedre til appens nuværende adfærd og undgår kunstige krav i weben.

## Konfliktretning

V1-regel:
- nyeste `review.updatedAt` vinder hele review-recorden
- hvis `updatedAt` er ens, vinder reviewet med flest udfyldte felter
- hvis begge er lige fyldige, vinder længste `summary`

Begrundelse:
- det er langt enklere end feltniveau-merge for en rig reviewstruktur
- det passer bedre til brugerens mentale model af “mit seneste review”
- det reducerer risikoen for mærkelige hybrids mellem app og web

## App- og webkonsekvens

### App
- eksisterende review-UI og `VisitedStore.StadiumReview` er den funktionelle reference
- app-boundary skal beskytte sync- og backendlaget, ikke oversætte til en anden reviewmodel

### Web
- web skal gradvist bygges op til samme reviewfelter som appen
- første webflow må gerne være smallere i UI-omfang, men ikke i datamodel

## Hvad der bevidst ikke tages nu
- fotos som del af reviewet
- flere review-records pr. stadion
- offentlig deling eller sociale features

## Næste arbejde

1. beskrive backend/read-write-kontrakten for reviews
2. lave en tydelig app-boundary for review-sync uden at opfinde en anden model
3. derefter implementere ét bevidst review-flow i app og web
