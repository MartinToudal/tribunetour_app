# Stadium Detail Implementation Plan

Dette dokument omsætter `STADIUM_DETAIL_ALIGNMENT.md` til en konkret implementeringsplan.

Målet er at ensrette stadiondetaljen på tværs af app og web uden at tage et stort, risikabelt redesign i ét hug.

## Overordnet strategi

Vi implementerer i tre lag:

1. struktur
2. komponentisering
3. polish og ensretning

Det betyder, at vi først får rækkefølgen og informationshierarkiet rigtigt, derefter samler UI i tydeligere komponenter, og til sidst justerer visuel konsistens.

## Målbillede

Begge platforme skal ende med denne fortælling:

1. identitet og status
2. næste bedste handling
3. kommende muligheder
4. min relation til stadion
5. fakta og metadata

## App-plan

### Fase 1: Struktur

Formål:

- få informationshierarkiet tættere på målstrukturen

Konkrete ændringer:

1. Indfør en tydelig `hero`-sektion øverst
   - klubnavn
   - stadionnavn
   - by
   - liga
   - land hvis relevant

2. Gør besøgt-status mere integreret i toppen
   - enten som del af hero-kortet
   - eller som en lille `VisitStatusCard` umiddelbart under hero

3. Behold `Næste kamp` som første handlingssektion

4. Behold `Kommende kampe her` som separat oversigtssektion

5. Flyt personligt indhold op som samlet blok
   - noter
   - billeder
   - anmeldelser

6. Flyt sekundære metadata ned
   - koordinater
   - tekniske detaljer
   - evt. intern kode

Primære filer:

- [StadiumDetailView.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/StadiumDetailView.swift)

### Fase 2: Komponentisering

Formål:

- gøre app-visningen mere vedligeholdelig og nemmere at spejle på web

Konkrete komponenter:

- `StadiumHeroCard`
- `VisitStatusCard`
- `NextFixtureCard`
- `UpcomingFixturesSection`
- `PersonalStadiumContentSection`
- `StadiumFactsSection`

Det behøver ikke være separate filer fra dag ét, men de bør mindst blive tydelige som undersektioner eller private views.

Primære filer:

- [StadiumDetailView.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/StadiumDetailView.swift)

### Fase 3: Polish

Formål:

- få stadiondetaljen til at føles mere som del af det opdaterede app-UX

Konkrete justeringer:

- sikre visuel sammenhæng med `Kampe`, `Plan` og `Min tur`
- sikre light/dark mode på alle CTA’er og kort
- sikre konsistent spacing mellem sektioner
- bruge samme badge- og statuslogik som andre skærme

## Web-plan

### Fase 1: Struktur

Formål:

- flytte siden tættere på samme fortælling som appen

Konkrete ændringer:

1. Behold hero og top-CTA’er

2. Gør besøgt-status og personlig relevans tydeligere i den første del af siden

3. Behold `Næste kamp` som selvstændig handlingssektion

4. Flyt personligt indhold op før fakta
   - det personlige indhold skal ikke ligge som en sen sidecar-effekt

5. Flyt `Fakta` efter `Min relation til stadion`

Primære filer:

- [page.tsx](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/app/stadiums/%5Bid%5D/page.tsx)
- [StadiumDetailClient.tsx](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/app/stadiums/%5Bid%5D/StadiumDetailClient.tsx)

### Fase 2: Komponentisering

Formål:

- få siden over i tydelige, genbrugelige stykker

Konkrete komponenter:

- `StadiumHero`
- `StadiumVisitStatus`
- `NextFixtureCard`
- `UpcomingFixturesList`
- `PersonalStadiumContent`
- `StadiumFactsCard`

Hvis nogle allerede findes delvist, bør de strammes op i stedet for at blive genopfundet.

### Fase 3: Polish

Formål:

- få web og app til at føles som samme produkt, ikke bare samme data

Konkrete justeringer:

- ensret badge-sprog
- ensret sektionstitler
- ensret CTA-hierarki
- sikre at premium-landefølelse og statusoplysninger opfører sig som i appen

## Fælles regler vi skal fastholde

Disse må ikke divergere mellem platformene:

- besøgt-status skal betyde det samme
- næste kamp skal findes på samme logik
- kommende kampe skal afgrænses efter samme princip
- land, liga og pyramide skal præsenteres i samme rækkefølge
- personligt indhold skal forstås som brugerens relation til stadionet

## Anbefalet rækkefølge

### Trin 1

App struktur først.

Hvorfor:

- appen har størst behov for hero/oprydning i toppen
- det er hurtigst at mærke forbedringen
- appens personlige indhold er allerede stærkt og kan organiseres bedre

### Trin 2

Web struktur bagefter.

Hvorfor:

- web har allerede en stærk hero
- den største gevinst der er at flytte personlig relation frem og fakta tilbage

### Trin 3

Komponentisering på begge platforme.

Hvorfor:

- når strukturen er bevist god, giver det mening at pakke den ind i genbrugelige moduler

### Trin 4

Polish og endelig visuel ensretning.

## Arbejdsblokke

### Blok A: App

- redesign toppen i appens stadiondetalje
- saml personlig relation i én tydelig blok
- flyt fakta ned
- sanity-check i light og dark mode

### Blok B: Web

- løft besøgt-status og personlig relation op
- flyt fakta ned
- sikre at hero, næste kamp og kommende kampe danner samme historie som appen

### Blok C: Fælles

- gennemgå labels og sektionstitler
- gennemgå badges og CTA’er
- dokumentér endelige komponentnavne hvis vi gør dem til egentlige moduler

## Definition af done

Stadiondetalje-piloten er færdig, når:

- app og web bruger samme indholdsstruktur
- hero, status, næste kamp og personlig relation ligger samme sted i fortællingen
- personligt indhold føles centralt på begge platforme
- fakta er tilgængelige, men sekundære
- light og dark mode føles bevidst styret

## Efter piloten

Når stadiondetaljen er på plads, bør næste kandidater være:

1. `MatchCard`
2. `StadiumCard`
3. `ScopeFilter`

Det er de komponenter, der hurtigst vil sprede den fælles designretning videre ud i produktet.
