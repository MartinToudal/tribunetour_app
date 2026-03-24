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
