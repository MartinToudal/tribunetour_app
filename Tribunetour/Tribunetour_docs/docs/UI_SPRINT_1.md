# UI Sprint 1

Dette dokument omsætter `UI_RELEASE_ROADMAP.md` til en konkret første sprint.

Sprint 1 er designet til at være:

- lille nok til at være overskuelig
- stor nok til at give mærkbar UX-værdi
- sikker nok til at vi kan release efter hvert deltrin

## Sprintmål

Det overordnede mål for Sprint 1 er:

- at tage de første konkrete skridt mod et mere ensartet Tribunetour-design på app og web
- uden at sætte `main` i en mellemtilstand

## Sprintens 4 leverancer

### Leverance 1: Stadium detail i app

Repo:

- app

Formål:

- gøre stadiondetaljen mere hero-drevet og mere i tråd med den fælles UI contract

Opgaver:

1. indfør tydeligere hero-struktur øverst
2. gør besøgt-status mere integreret
3. bevar `Næste kamp` som første handlingssektion
4. saml noter, billeder og anmeldelser tydeligere som “min relation til stadion”
5. flyt sekundære fakta længere ned

Ship-værdi:

- høj

Risiko:

- lav til mellem

Kan releases alene:

- ja

### Leverance 2: Stadium detail på web

Repo:

- web

Formål:

- få web til at følge samme historie som appen

Opgaver:

1. behold hero
2. gør personlig relation mere synlig tidligere på siden
3. flyt fakta efter personlig relation
4. gør næste kamp til endnu tydeligere primær handling

Ship-værdi:

- høj

Risiko:

- lav

Kan releases alene:

- ja

### Leverance 3: Første map-oprydning i app

Repo:

- app

Formål:

- reducere støj og gøre kortet mere brugbart før flere lande presser det yderligere

Opgaver:

1. reducér pin-støj
2. gør scope tydeligere omkring kortet
3. sørg for at mini-kortet føles mere som næste handling og mindre som teknisk overlay

Ship-værdi:

- mellem til høj

Risiko:

- mellem

Kan releases alene:

- ja

### Leverance 4: Første map-forbedring på web

Repo:

- web

Formål:

- gøre web-kortet mere brugbart som udforskningsflade

Opgaver:

1. forbedr default-scope
2. gør kortets underliste mere relevant end “første 6”
3. tydeliggør hvad kortet viser og hvorfor

Ship-værdi:

- mellem

Risiko:

- lav til mellem

Kan releases alene:

- ja

## Anbefalet rækkefølge

Sprint 1 bør tages i denne rækkefølge:

1. app stadiondetalje
2. web stadiondetalje
3. app kort
4. web kort

Hvorfor:

- stadiondetaljen har størst brugeroplevelsesværdi
- den skaber hurtigt bedre sammenhæng mellem app og web
- kortet er vigtigt, men en lidt mere kompleks UX-flade

## Release-punkter

For at beskytte release-evnen bør vi tænke i fire mulige stop-punkter:

### Stop-punkt A

Efter app stadiondetalje.

Det er allerede en værdifuld release.

### Stop-punkt B

Efter web stadiondetalje.

Nu er den første fælles pilotskærm på plads på begge platforme.

### Stop-punkt C

Efter app kort-oprydning.

Nu er den mest presserede kort-UX i appen håndteret.

### Stop-punkt D

Efter web kort-oprydning.

Nu er hele Sprint 1 i mål.

## Definition af done for hver leverance

Hver leverance er først færdig når:

- light og dark mode er tænkt bevidst ind
- der ikke er åbenlyse halve tilstande i UI
- den nye struktur er forståelig uden forklaring
- vi ville være komfortable med at sende den alene

## Hvad Sprint 1 bevidst ikke skal gøre

For at beskytte release-evnen skal Sprint 1 ikke forsøge at:

- løse hele premium-UI’en
- bygge nyt fælles scope-system fra bunden
- lave backend-drevet reference-data
- indføre clustering på web-kortet
- lave et fuldt visuelt redesign af hele appen

Det kommer senere.

## Output efter Sprint 1

Hvis Sprint 1 lykkes, står vi med:

- en fælles pilotskærm på plads på app og web
- et mindre presset kort på begge platforme
- et stærkere fundament for næste UI-sprint
- fortsat release-klar `main` hele vejen

## Forslag til Sprint 2

Når Sprint 1 er færdig, er de bedste kandidater til Sprint 2:

1. `MatchCard`
2. `StadiumCard`
3. `ScopeFilter`
4. fælles CTA- og surface-regler
