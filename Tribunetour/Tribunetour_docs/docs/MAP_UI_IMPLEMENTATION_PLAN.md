# Map UI Implementation Plan

Dette dokument omsætter `MAP_UI_REVIEW.md` til en konkret implementeringsplan.

Målet er at gøre kortet mere skalerbart, mere hjælpsomt og mere visuelt sammenhængende med resten af Tribunetour.

## Overordnet retning

Kortet skal gå fra at være en rå geografisk oversigt til at være en styret udforskningsflade.

Det betyder:

1. scope først
2. relevans før alt-data
3. tydeligere hierarki på pins og overlays
4. bedre bro mellem kort og næste handling

## Målbillede

På både app og web skal kortet besvare:

- hvilket område ser jeg nu
- hvilke stadioner er mest relevante
- hvad er næste oplagte handling

## App-plan

### Fase 1: Struktur og scope

Formål:

- gøre kortet lettere at forstå med flere lande

Konkrete ændringer:

1. Gør scope mere tydeligt i toppen af stadionskærmen
   - aktivt land eller aktive pakker skal føles som en central kontekst

2. Lad standardkortet tage udgangspunkt i brugerens hjemland eller aktive scope
   - ikke kun “fit everything”

3. Behold mini-kortet i bunden, men sørg for at det tydeligt afspejler scope

Primære filer:

- [ContentView.swift](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/ContentView.swift)

### Fase 2: Pin-hierarki

Formål:

- reducere visuel støj

Konkrete ændringer:

1. Gør visited og not visited tydeligere forskellige
2. Overvej at fjerne altid-synlige tekstlabels over hver pin
3. Brug enklere, renere pin-markører
4. Lad labels eller detaljer komme i mini-kortet i stedet for direkte på alle pins

Det er sandsynligvis den hurtigste gevinst i appen.

### Fase 3: Relevans

Formål:

- gøre kortet mere nyttigt som beslutningsværktøj

Konkrete ændringer:

1. Introducér en lille sektion eller kontekstlinje over kortet:
   - fx antal stadioner i scope
   - antal ubesøgte
   - hvad kortet viser lige nu

2. Lad mini-kortet tydeligere pege på næste handling:
   - detaljer
   - markér besøgt
   - åbne i Maps

3. Overvej på sigt en lille “mest relevante” liste under kortet, hvis kortet alene bliver for støjende

## Web-plan

### Fase 1: Struktur og default-scope

Formål:

- gøre web-kortet mere brugbart ved flere lande

Konkrete ændringer:

1. Lad standardvisningen tage udgangspunkt i aktivt scope i stedet for implicit “hele kortet”
2. Gør country/scope-filteret endnu tydeligere som primær kontrol
3. Gør teksten over kortet mere handlingsorienteret

Primære filer:

- [page.tsx](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/app/map/page.tsx)
- [MapView.tsx](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Website%20repo/app/%28site%29/_components/MapView.tsx)

### Fase 2: Relevante kort under kortet

Formål:

- gøre underlisten nyttigere

Konkrete ændringer:

1. Erstat “første 6 stadioner” med en mere meningsfuld logik
   - nærmeste i scope
   - ubesøgte
   - næste oplagte

2. Gør relationen mellem kort og cards tydeligere

### Fase 3: Clustering og pin-hierarki

Formål:

- sikre at kortet ikke kollapser ved flere lande

Konkrete ændringer:

1. Indfør clustering, når datamængden vokser nok
2. Gør besøgte pins sekundære
3. Gør ubesøgte eller anbefalede pins mere fremtrædende

Dette er vigtigere på web end i appen, fordi Leaflet-kortet hurtigere bliver uoverskueligt.

## Fælles farveretning

Brugeren oplever web som mere visuelt modent, og det er et godt signal.

Derfor bør web være reference for farveretningen i kortarbejdet.

Konkrete regler:

1. Brug semantiske farveroller
   - visited
   - unvisited
   - recommended
   - muted

2. Sørg for at overlays og kort bruger bevidste surfaces

3. Sørg for at samme farverolle betyder det samme på app og web

## Fælles komponentretning

Vi bør ende med disse parallelle komponenttyper:

- `MapScopeHeader`
- `MapSurface`
- `MapPin`
- `MapSelectionCard`
- `MapRelevantStadiumList`

De behøver ikke være delt kode, men de skal være samme koncept.

## Anbefalet rækkefølge

### Trin 1

App:

- mindre pin-støj
- tydeligere scope
- mere bevidst mini-kort

### Trin 2

Web:

- bedre underliste
- bedre default-scope
- mere tydelig sammenhæng mellem kort og næste handling

### Trin 3

Begge:

- fælles farveretning
- fælles overlays og statusregler

### Trin 4

Web først, derefter app:

- clustering eller mere avanceret pin-logik

## Definition af done

Map-piloten er lykkedes, når:

- kortet stadig er brugbart med flere lande
- brugeren forstår hvad der vises og hvorfor
- visuel støj er reduceret
- kortet føles som en hjælper, ikke bare et lager af pins
- web og app bruger samme UX-logik

## Prioritet i den samlede UI-plan

Map bør være den næste store pilot efter stadiondetaljen.

Den anbefalede samlede rækkefølge er:

1. stadiondetalje
2. kort
3. cards og filters
4. bredere visuel ensretning
