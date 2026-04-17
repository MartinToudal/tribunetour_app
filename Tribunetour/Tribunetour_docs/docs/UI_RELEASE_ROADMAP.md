# UI Release Roadmap

Dette dokument samler UI-arbejdet i en release-sikker roadmap.

Målet er ikke bare at forbedre design og UX. Målet er at gøre det på en måde, hvor Tribunetour som udgangspunkt altid kan releases.

## Grundprincip

Vi arbejder i små, selvstændige forbedringer på `main`.

Hver ændring skal så vidt muligt:

- kunne stå alene
- forbedre produktet uden at kræve efterfølgende “redningsarbejde”
- være testbar i sig selv
- være sikker at shippe, også hvis vi stopper midt i roadmapen

Det betyder:

- ingen store halvfærdige redesigns
- ingen lange perioder hvor app eller web er “mellem to versioner”
- ingen afhængighed af at 4-5 andre UI-opgaver først lander

## Release-regler

Hver UI-opgave bør følge disse regler:

1. ingen brud på eksisterende flows
2. light og dark mode skal være tænkt ind fra starten
3. app og web må gerne forbedres i forskudt rækkefølge, men hver ændring skal være produktmæssigt sammenhængende
4. hvis en ændring kræver større arkitektur, skal den deles op i:
   - bagvedliggende forberedelse
   - UI-forbedring
   - eventuel polish
5. `main` skal altid være i en release-klar tilstand

## Prioritetsmodel

Vi prioriterer efter denne rækkefølge:

1. høj brugeroplevelsesværdi
2. lav risiko
3. forbedrer sammenhæng mellem app og web
4. skaber bedre fundament for flere lande og premium

## Roadmap

### Fase 1: Små sikre gevinster

Formål:

- fortsætte UX-løftet uden at røre for meget på én gang

Opgaver:

1. Stadium detail pilot i app
2. Stadium detail pilot på web
3. Map scope- og pin-oprydning i app
4. Mere relevant kort-underliste og bedre default-scope på web

Hvorfor denne fase er release-sikker:

- hver opgave kan stå alene
- ingen af dem kræver ændring i entitlement-model eller backend
- forbedringerne er synlige og begrænsede

### Fase 2: Fælles komponentretning

Formål:

- sikre at app og web begynder at ligne samme produkt mere tydeligt

Opgaver:

1. ensret `MatchCard`
2. ensret `StadiumCard`
3. ensret `EmptyState`
4. ensret primære/sekundære CTA-regler

Hvorfor denne fase er release-sikker:

- vi ændrer præsentation, ikke kerneflows
- vi kan tage komponent for komponent
- hver komponent kan rulles ud uden at de andre er færdige

### Fase 3: Scope og premium-UI

Formål:

- gøre flere lande og premium mere forståeligt i UI

Opgaver:

1. redesign af scope-filter fra enkel landelogik til mere skalerbar model
2. tydeligere “mine pakker” eller “aktive områder”
3. UI-støtte til `premium_full` når den model bliver bygget

Hvorfor denne fase er release-sikker:

- først når backend-reglen findes
- kan bygges som additive UI-lag
- eksisterende simple model kan fortsat fungere indtil ny model er helt klar

### Fase 4: Visuel ensretning

Formål:

- løfte appens visuelle modenhed tættere på web

Opgaver:

1. fælles farveroller
2. fælles surface/kort-regler
3. fælles badge- og statuslogik
4. fælles spacing- og sektionstoner

Hvorfor denne fase er release-sikker:

- kan tages stykvist
- forbedrer udseende uden at tvinge stort layoutskifte

## Konkrete næste skridt

### Næste 3 opgaver

1. implementér stadiondetalje-piloten i app
2. implementér stadiondetalje-piloten på web
3. lav første map-oprydning i app

Det er den bedste kombination af:

- høj værdi
- lav risiko
- tydelig fremdrift

## Opgaver vi bevidst ikke bør blande ind for tidligt

Disse er vigtige, men bør ikke pakkes ind i de første UI-sprints:

- stor backend-drevet reference-data refaktor
- fuld premium-full arkitektur hvis den ikke er implementeret endnu
- clustering og større kort-tekniske skift på begge platforme samtidig
- stort visuelt redesign af hele appen på én gang

De ting er bedre som egne spor.

## Definition af “klar til release”

En UI-iteration er klar til release når:

- den er visuelt sammenhængende i både light og dark mode
- den ikke efterlader åbenlyse halve tilstande
- den ikke introducerer nyt premium- eller scope-kaos
- app og web stadig føles som samme produktretning
- hvis vi stopper her, er resultatet stadig noget vi er stolte af at sende

## Arbejdsmodel

Den anbefalede arbejdsmodel er:

1. dokumentér retning
2. implementér lille pilot
3. sanity-check på app/web
4. commit og push
5. gå videre til næste lille blok

Det er den bedste måde at beskytte release-evnen på.

## Kort anbefaling

Hvis målet er løbende release-evne, så bør vi arbejde efter denne tommelfingerregel:

- én UX-idé
- én afgrænset skærm eller komponent
- én release-sikker leverance ad gangen

Det er langsommere end et stort redesign på papiret, men langt stærkere i praksis.
