# Tribunetour UI Contract

Dette dokument beskriver den fælles UX- og UI-retning for app og web.

Målet er ikke pixelperfekt enshed på tværs af SwiftUI og web, men at de to flader føles som det samme produkt, bygger på samme regler og fortæller samme historie.

## Formål

UI contract'et skal sikre, at:

- app og web prioriterer information på samme måde
- nye features som premium-lande og league packs kan indføres uden at skabe UX-brud
- vi kan bygge platform-specifikke komponenter, der stadig føles som samme produkt
- vi kan diskutere designbeslutninger ud fra fælles principper i stedet for enkeltskærme

## Produktfortælling

Tribunetour er et personligt stadionrejse-produkt.

Kernen er:

1. opdag stadions
2. find kampe
3. planlæg næste tur
4. byg din personlige stadionrejse

Det oversættes til disse hovedområder:

- `Stadions`: opdagelse
- `Kampe`: muligheder
- `Plan`: anbefaling og beslutning
- `Min tur`: progression, motivation og personlig historik

## Designprincipper

### 1. Først næste handling

Skærmen skal hurtigt fortælle brugeren, hvad næste naturlige handling er.

Vi viser ikke først alle kontroller. Vi viser først retning.

### 2. Status før detaljer

Progression, relevans og adgang vises før de mere tekniske eller sekundære detaljer.

### 3. Samme historie på tværs af flader

Et stadion, en kamp og en plan skal fortælles i samme rækkefølge på web og app, også når layoutet ikke er identisk.

### 4. Premium uden forvirring

Ekstra lande og league packs skal føles som naturlige udvidelser af produktet, ikke som intern adgangslogik der lækker ud i UI.

### 5. Theme-aware som standard

Alle komponenter designes bevidst til både light og dark mode. Vi må ikke være afhængige af tilfældige system-defaults for primære handlinger.

## Informationshierarki

Den generelle regel for Tribunetour er:

1. hvad bør jeg gøre nu
2. hvor står jeg
3. hvilke alternativer har jeg
4. hvilke avancerede valg kan jeg justere

Det betyder i praksis:

- anbefaling før kontrolpanel
- progression før rå data
- indhold før avancerede filtre

## Scope og adgang

Scope beskriver, hvilke lande eller league packs brugeren aktuelt ser.

UI-regler:

- scope skal vises tydeligt, men kompakt
- scope må ikke dominere skærmen
- scope skal kunne udvides til flere lande uden at UI bryder sammen
- premium-adgang skal forstås som "det du har adgang til", ikke som teknisk jargon

På sigt bør scope være et mere fleksibelt filter eller sheet for aktive pakker og lande.

## Fælles komponenttyper

Følgende komponenter skal findes på både web og app, som platform-specifikke implementeringer med samme struktur og formål.

### `ScopeFilter`

Viser aktivt scope:

- hjemland
- valgte lande
- aktive premium-pakker

### `MatchCard`

Skal som minimum kunne vise:

- dato og tidspunkt
- hjemmehold og udehold
- stadion
- by
- liga
- besøgt-status
- plan-status eller næste handling

### `StadiumCard`

Skal som minimum kunne vise:

- klubnavn
- stadionnavn
- liga
- land
- afstand
- besøgt-status

### `ProgressCard`

Bruges til:

- milepæle
- liga-progress
- næste mål
- achievements

### `RecommendationCard`

Bruges til:

- bedste mulighed
- gode alternativer
- næste oplagte stadion

### `EmptyState`

Skal have samme tone og struktur på tværs af platforme:

- kort forklaring
- hvad brugeren kan gøre nu
- evt. en tydelig handling

### `SectionHeader`

Skal have:

- klar titel
- evt. kort forklaring
- evt. sekundær handling

### `PrimaryActionButton`

Primære CTA'er skal:

- være tydelige
- have samme prioritet på begge platforme
- være designet bevidst til light og dark mode

### `StatusBadge`

Bruges fx til:

- `Nyt stadion`
- `Besøgt`
- `I dag`
- `Premium`

## Tokens

Web og app må gerne have forskellige implementationer, men de skal bruge samme semantiske tokens.

### Farver

- `surface.primary`
- `surface.secondary`
- `surface.raised`
- `text.primary`
- `text.secondary`
- `text.muted`
- `accent.brand`
- `accent.success`
- `accent.warning`
- `border.subtle`
- `border.strong`

### Spacing

- `space.xs`
- `space.sm`
- `space.md`
- `space.lg`
- `space.xl`

### Radius

- `radius.sm`
- `radius.md`
- `radius.lg`
- `radius.xl`

### Typografiroller

- `type.hero`
- `type.section`
- `type.cardTitle`
- `type.body`
- `type.meta`
- `type.badge`

## Skærmregler

### Stadions

Formål:

- hjælpe brugeren med at opdage relevante stadions

Prioritet:

1. søgning eller hurtig orientering
2. stadions som indhold
3. sekundære filtre

### Kampe

Formål:

- vise relevante muligheder hurtigt

Prioritet:

1. tidsvalg
2. tydelig liste over kampe
3. sekundære filtre i sheet eller panel

`Kampe` skal føles mere som et feed og mindre som et kontrolpanel.

### Plan

Formål:

- hjælpe brugeren med at vælge næste tur

Prioritet:

1. bedste mulighed
2. gode alternativer
3. min plan
4. alle muligheder

### Min tur

Formål:

- være produktets følelsesmæssige center

Prioritet:

1. progression
2. næste milepæl
3. næste oplagte stadion
4. achievements
5. fordelt på liga
6. historik og konto/sync

## Detailvisninger

### Stadiondetalje

Rækkefølge bør være:

1. hovedinfo og status
2. næste kamp
3. kommende kampe her
4. personligt indhold som noter, anmeldelser og fotos

### Kampdetalje

Rækkefølge bør være:

1. kampinfo
2. stadion og kontekst
3. relevans for brugeren
4. relaterede handlinger

## Premium og achievements

Achievements skal afspejle, at brugeren kan have:

- kun kernepakken
- enkelte premium-lande
- flere aktive lande

Derfor skelner vi mellem:

- `Grundachievements`
- `Premium achievements`

Regler:

- grund-achievements må ikke blive uforståelige, bare fordi flere lande er aktive
- premium-achievements må gerne være synlige som ekstra mulighed, men skal føles som en udvidelse, ikke som støj

## Fælles logik der skal deles

Disse regler må ikke opfindes forskelligt i app og web:

- pyramide-sortering pr. land
- labels og præsentation af ligaer
- visited-progression
- achievement-logik
- entitlement-regler
- hvordan scope filtrerer stadions, kampe, plan og stats

## Prioriteret ensretning

Første bølge:

1. `Stadiondetalje`
2. `MatchCard`
3. `StadiumCard`
4. `ScopeFilter`

Anden bølge:

1. `Plan`
2. `Min tur`
3. `EmptyState`
4. `PrimaryActionButton`

Tredje bølge:

1. premium-surface og league-pack UI
2. flere lande uden UX-brud
3. eventuelle admin- eller entitlement-flows

## Definition af succes

Vi er lykkedes med UI contract'et, når:

- app og web føles som samme produkt
- brugeren ikke skal genlære logik mellem platforme
- nye lande kan introduceres uden mærkbar UX-friktion
- light og dark mode begge føles som førstegangsborgere
- premium udvidelser føles naturlige og ikke påklistrede
