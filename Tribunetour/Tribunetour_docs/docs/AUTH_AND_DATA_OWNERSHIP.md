# Auth And Data Ownership

## Formål
Dette dokument definerer den tekniske retning for login, brugerdata og dataejerskab på tværs af app og web.

Målet er at undgå, at web og app udvikler to uforenelige modeller for:
- identitet
- brugerdata
- sync
- source of truth

## Nuværende situation

### iOS-app
Appen er i dag:
- local-first
- bygget med UserDefaults til hurtig lokal persistens
- med optional sync via CloudKit

Brugerdata ligger i dag i praksis i:
- lokal app-storage
- brugerens private CloudKit-database

Det betyder:
- data er pr. bruger
- data er ikke delt som en offentlig backend-model
- web har ikke automatisk adgang til de samme private data

### Web
Web bruger i dag login-retning via magic link og Supabase-orienteret auth/UI.

Web har allerede behov for at kunne vise eller gemme:
- besøg
- visited-status
- senere noter, planer og andre brugerdata

Det betyder, at websporet presser på for en mere klassisk backend-identitet end den nuværende app-model alene giver.

## Kerneproblem
Appen bruger i dag private iCloud/CloudKit-data.
Web kan ikke realistisk bygge en god tværplatformsoplevelse oven på brugerens private CloudKit-database alene.

Derfor skal vi være tydelige:
- enten forbliver app og web løst koblede
- eller også indfører vi en fælles backend-ejet brugerdata-model

Hvis målet er ét produkt på tværs af app og web, peger det mod en fælles backend-retning.

## Dataejerskab

### Reference-data
Reference-data er produktdata, som Tribunetour ejer og distribuerer:
- stadions
- klubber
- fixtures/kampe
- ligaer

Krav:
- fælles IDs på tværs af app og web
- versionsstyret distribution
- læsbar på alle klienter

Source of truth:
- Tribunetour-kontrolleret dataset

### Brugerdata
Brugerdata er personlige data, som brugeren ejer:
- besøg
- visited date
- noter
- anmeldelser
- billeder
- planer

Krav:
- tydelig identitet knyttet til data
- samme forventning på tværs af app og web
- senere konfliktregler og sync-politik

Source of truth bør på sigt være:
- én backend-ejet brugerdata-model

## Auth-retning

### Mål
Brugeren skal have én identitet på tværs af app og web.

Det betyder:
- samme login-type
- samme brugerprofil
- samme adgang til egne data

### Anbefalet retning
Brug magic link / e-mail auth som første fælles identitetsmodel.

Begrundelse:
- lav friktion
- matcher den nuværende web-retning
- enkel at forklare for brugeren
- god overgang mellem hobbyprojekt og rigtigt produkt

### Hvad auth ikke må være
Auth må ikke ende som:
- kun en web-feature
- kun et tekniklag uden produktbetydning
- noget der giver forskellige datasæt på web og app uden at det er tydeligt

## Anbefalet overgangsmodel

### Fase 1: Sandhed om nuværende tilstand
Indtil videre gælder:
- appens private CloudKit-data er ikke samme datalag som web
- web kan have login og brugerstate, men skal være tydelig om begrænsninger
- vi må ikke lade brugeren tro, at alt synker på tværs, hvis det ikke gør

### Fase 2: Fælles identitet
Indfør samme loginretning i app og web.

Målet er:
- at brugerens identitet bliver fælles
- selv før alle brugerdata er fuldt migreret

Status i app-koden:
- appen har nu et eksplicit `AppAuthSession` seam
- shared/hybrid visited backends henter senere token via denne session
- visited sync mode kan vælges via et runtime-flag til intern test
- login-flowet er endnu ikke aktivt i UI

### Fase 3: Fælles brugerdata
Flyt eller spejl udvalgte brugerdata til fælles backend-model.

Prioriteret rækkefølge:
1. visited status
2. visited date
3. noter
4. planer
5. anmeldelser
6. billeder

Det giver mest mening, fordi:
- visited status er den vigtigste bro mellem app og web
- det er den simpleste brugerdata-model at gøre fælles først
- det unlocker `Min tur`, filtrering og kamp-/stadionflows på tværs

## Beslutninger

### 1. CloudKit alene er ikke nok til tværplatform
CloudKit private database er fin til app-first sync, men ikke til en egentlig web+app-univers-model alene.

### 2. Reference-data og brugerdata skal skilles hårdt ad
Vi må ikke blande “fælles stadiondata” og “brugerens private besøg” sammen som om de har samme ejerskab.

### 3. Første fælles brugerdata bør være visited state
Det er den mindst komplekse og mest værdifulde fælles mængde.

### 4. Login skal forklares som adgang til brugerens egen Tribunetour
Ikke som en teknisk tilføjelse.

## Produktkonsekvenser

### Web
Web kan fortsætte med:
- login UI
- besøg/visited-funktioner
- `Min tur`
- kampfiltre koblet til besøgsstatus

Men kun hvis vi er ærlige om datamodellen.

### App
Appen kan forblive stabil nu.
Ingen migration skal presses ind, mens App Store-sporet lige er landet.

### Senere fælles spor
Når appen åbnes igen for større ændringer, bør vi tage:
- fælles auth
- fælles visited state
- afklaring af migration fra privat CloudKit-model til fælles backend-model eller hybrid-model

## Hybrid-model
Der er sandsynligvis brug for en overgangsperiode med hybrid drift:
- app bevarer lokal-first adfærd
- web bruger fælles auth/backendløsning
- visse brugerdata spejles eller migreres gradvist

Det er acceptabelt, hvis vi holder reglerne skarpe.

Det er ikke acceptabelt, hvis:
- brugerens data er uklare
- samme handling giver forskellige resultater på web og app uden forklaring

## Besluttet steady-state for visited

Denne beslutning er nu låst for `visited`:

### 1. Shared backend er autoritativ efter bootstrap
Når en bruger har gennemført app-bootstrap eller allerede har shared `visited`-state etableret, er shared backend den autoritative kilde for `visited`.

Det betyder:
- web læser og skriver shared backend
- app læser og skriver shared backend som primær fælles model
- klienterne må ikke fortsætte med at behandle appens lokale historik som den langsigtede sandhed bagefter

### 2. Appen er kun autoritativ i bootstrap-øjeblikket
Appens eksisterende lokale data er kun sandheden i selve bootstrap-overgangen.

Det betyder:
- appens snapshot bruges til at etablere første fælles tilstand
- denne særregel ophører, når bootstrap er markeret som gennemført for brugeren

### 3. CloudKit er sekundært efter bootstrap
CloudKit er ikke den fælles source of truth for `visited` efter bootstrap.

CloudKits rolle efter bootstrap er:
- lokal kompatibilitet i overgangsperioden
- eventuel mirror/legacy-støtte, hvis appen stadig har brug for det internt

CloudKit er ikke:
- autoritativ tværplatformssandhed
- stedet hvor web skal læse fra
- et separat beslutningslag for brugerens endelige `visited`-status

### 4. Konfliktretning i steady-state
Efter bootstrap skal konflikter løses inden for shared-modellen, ikke ved at falde tilbage til “appen har nok ret”.

Det betyder:
- shared backend-kontrakten styrer konfliktreglerne
- app og web skal behandles som klienter mod samme sandhed

### 5. Produktkonsekvens
Når denne steady-state er aktiv, må produktcopy ikke længere sige:
- at appen generelt er den primære sandhed
- at brugeren bør rette status i appen først som normalregel

Den type copy er kun korrekt i den snævre migrationsperiode før bootstrap er afsluttet.

## Shared vs app-only datamatrix

Denne matrix låser den aktuelle produktretning for brugerdata, så app og web ikke udvikles ud fra forskellige antagelser.

| Dataområde | Status | Autoritativ model lige nu | Web | App | Note |
| --- | --- | --- | --- | --- | --- |
| `visited` | Shared nu | Shared backend efter bootstrap | Læs/skriv | Læs/skriv | Fælles kerneområde |
| `visitedDate` | Shared nu | Shared backend efter bootstrap | Skrives sammen med `visited` | Del af `VisitedStore` + shared sync | Behandles som del af samme model |
| `notes` | Shared | Shared notes-backend + lokal app-seam | Delt mellem app og web | Første version bygget | Verificeret begge veje, men ikke realtime |
| `review` | App-only | `VisitedStore` / lokal + CloudKit legacy | Ikke delt | Fuldt understøttet | Rig datamodel med scores og kategori-noter |
| `photos` | App-only | Lokal filstorage + CloudKit legacy | Ikke delt | Fuldt understøttet | Højere kompleksitet og konfliktflade |
| `weekend plan` | App-only | `WeekendPlanStore` / lokal + CloudKit | Ikke delt | Fuldt understøttet | Separat brugerdata-spor |
| `achievements/progression UI` | App-only | Lokal app-state | Ikke delt | Understøttet | Kan vises afledt, men er ikke delt datalag |

### Konsekvens pr. kategori

#### Shared nu
- `visited`
- `visitedDate`

Disse data må behandles som fælles tværplatformsdata og er grundlaget for:
- `Min tur`
- visited-filtre
- visited-status på stadioner og kampe

#### App-only
- `notes`
- `review`
- `photos`
- `weekend plan`
- achievements og lokal progressionstilstand

Disse data må ikke implicit loves som tværplatformsdata i produktcopy eller UI.

#### Shared senere
Følgende områder er kandidater til senere fælles model, men er ikke besluttet som næste implementering:
1. `notes`
2. `review`
3. `weekend plan`
4. `photos`

Den anbefalede rækkefølge afspejler implementeringsrisiko:
- `notes` er lettest at dele efter `visited`
- `review` kræver kontrakt for rig struktur
- `weekend plan` kræver beslutning om web-scope
- `photos` er mest komplekst pga. storage, metadata og konfliktregler

## Næste shared dataområde

Den næste fælles datamodel efter `visited` er nu besluttet til at være:
- `notes`

Første kontraktniveau for dette spor ligger i:
- `NOTES_SHARED_MODEL.md`

### Hvorfor `notes`
`notes` er det mest naturlige næste skridt, fordi:
- det ligger tæt på den eksisterende `visited`-model
- det giver reel brugeroplevelsesværdi på tværs af app og web
- konfliktfladen er mindre end for fotos og reviews
- det kræver ikke, at web først får hele plan-flowet eller review-UI’et

### Hvad denne beslutning betyder
Det betyder ikke, at `notes` skal implementeres med det samme i alle flader.

Det betyder:
- næste shared dataarbejde skal tage udgangspunkt i `notes`
- `review`, `photos` og `weekend plan` tages ikke som parallelle dataspot nu
- hvis et nyt integrationsspor kræver endnu et shared dataområde, skal det vurderes op mod denne prioritet

### Hvad der bevidst ikke tages nu
- `review`
  - rigere struktur og større UI-konsekvens
- `photos`
  - høj storage- og sync-kompleksitet
- `weekend plan`
  - kræver først tydeligere beslutning om web-scope og personlig planmodel

#### Ikke planlagt nu
Der er ikke taget beslutning om at gøre achievements til shared backend-data.
Hvis web senere skal vise mere progression, bør det i første omgang afledes fra shared `visited`, ikke fra en ny shared achievements-model.

## Konkrete produktregler

1. Web må kun vise og redigere data, der faktisk er shared eller eksplicit web-ejet.
2. Appen må fortsat eje richer stadiondata, så længe det er tydeligt, at de ikke deles endnu.
3. Nye integrationsopgaver skal placeres i én af fire kasser:
   - `shared nu`
   - `shared senere`
   - `app-only`
   - `ikke planlagt`
4. Hvis et dataområde flyttes fra `app-only` til `shared senere`, skal der først skrives en backend-kontrakt og en brugerforventning.

## Hvad vi ikke beslutter endnu
Dette dokument låser ikke:
- specifikt backend-skema
- endelig database-teknologi
- endelig migrationsstrategi for fotos og reviews

Det låser kun retningen:
- fælles identitet
- fælles reference-data
- gradvis konvergens af brugerdata

## Næste konkrete arbejde
1. definere første fælles brugerdata-model for `visited`
2. beskrive backend- og sync-retning for web/app
3. bruge den model som grundlag for næste web-iteration

Se `VISITED_SHARED_MODEL.md` for den konkrete første shared model.
