# Hybrid Sync Test Plan

## Formål
Denne plan beskriver, hvordan Tribunetours nye hybrid visited-sync skal testes sikkert på få interne enheder, før noget bredere aktiveres.

Målet er:
- at holde appen som source of truth i overgangsperioden
- at verificere at appens data kan spejles til shared backend
- at undgå at web eller shared backend overskriver korrekt app-data blindt

## Forudsætninger
Før testen starter, skal dette være sandt:
- web bruger allerede shared `visited`
- Supabase-tabellen `visited` findes og virker
- appen bygger grønt
- appen kører stadig default i `cloudKitPrimary`
- testerne er kun dig og din makker

## Testprincip
Hybridtesten skal køres som en kontrolleret intern test, ikke som bred rollout.

Regel:
- appen er stadig autoritativ
- shared backend er sekundær i første testfase
- vi tester spejling og konsistens, ikke autoritetsskifte

## Testenheder
Anbefalet opsætning:
1. din iPhone med dine rigtige app-data
2. din makkers iPhone med hans rigtige app-data
3. gerne en ekstra ren test-enhed eller simulator, hvis I vil validere tom-state og første-login-flow senere

## Runtime-mode
### Standard
- `CloudKit primær`

### Intern testmode
- `Hybrid forberedt`

Valg sker i appens `Interne værktøjer`.

Vigtigt:
- mode-skift gælder først efter genstart af appen
- ingen andre brugere skal sættes i anden mode end standard

## Fase 1: Baseline før hybrid
På hver test-enhed:
1. noter antal besøgte stadioner i appen
2. åbn 3-5 konkrete stadioner med kendte besøg
3. noter visited-status, dato, noter og evt. billeder
4. sammenlign med web

Forventning:
- forskelle må godt findes
- hvis der er forskelle, er appen den rigtige kilde

## Fase 2: Aktivér hybrid på én enhed
Start kun med din egen enhed.

Trin:
1. gå til `Interne værktøjer`
2. vælg `Hybrid forberedt`
3. luk appen helt
4. start appen igen
5. brug appen normalt i et par minutter

Kontroller:
- appen starter uden fejl
- visited-data ser uændrede ud
- billeder, noter og reviews er stadig synlige
- ingen tydelige sync-relaterede fejl i normal brug

## Fase 3: Write-test fra app til backend
På hybrid-enheden:
1. vælg et stadion der i forvejen er `ikke besøgt`
2. markér det som `besøgt`
3. hvis muligt: sæt besøgsdato eller note
4. vent kort
5. refresh web
6. tjek samme stadion på:
   - forsiden
   - `Min tur`
   - stadiondetalje

Forventning:
- appen viser ændringen med det samme
- web bør senere kunne afspejle samme ændring via shared backend
- hvis noget afviger, er appens status stadig den rigtige

## Fase 4: Reverse-test i appen
På samme hybrid-enhed:
1. tag et stadion der er `besøgt`
2. markér det som `ikke besøgt`
3. vent kort
4. refresh web

Forventning:
- appen beholder sin egen korrekte state
- shared backend bør få `visited = false` som soft state
- web bør på sigt vise samme status

## Fase 5: Web sammenligning
For hver ændring lavet i appen:
1. tjek at web ikke viser en ældre status efter refresh
2. tjek at `/`, `/my`, `/matches`, `/stadiums/[id]` og `/matches/[id]` er enige
3. hvis web afviger, notér det som sync-problem, ikke som brugerfejl

## Fase 6: Makkers enhed
Når din egen enhed er stabil:
1. gentag Fase 1-5 på din makkers enhed
2. brug kun 2-3 stadions i første omgang
3. undgå at teste for mange mutationer samtidig

## Hvad der ikke skal testes endnu
Følgende er bevidst ude af første hybridtest:
- delt fotosync mod shared backend
- delt review-sync mod shared backend
- delt note-sync mod shared backend
- autoritetsskifte væk fra appen
- bred rollout til flere brugere

## Log og observationer
For hver afvigelse bør I notere:
- enhed
- sync-mode
- stadion-id
- app-status før
- app-status efter
- web-status efter refresh
- om der var noter, dato eller billeder tilknyttet

## Go / No-Go
### Go til næste fase
- app-data ændrer sig ikke uventet ved hybrid-mode
- appen crasher ikke
- appens lokale/CloudKit-data forbliver intakte
- mindst simple visited-ændringer kan spores sikkert mod web/backend

### No-Go
- app mister eksisterende besøg
- billeder/noter/reviews forsvinder
- web overskriver korrekt app-data
- hybrid-mode giver ustabil opstart eller tydelige sync-fejl

## Næste fase efter grøn test
Hvis hybridtesten er grøn, er næste skridt:
1. gøre shared backend-url og auth-token reelt konfigurerbare
2. teste ægte spejling fra app til backend
3. derefter begynde at planlægge første login-flow i appen

## Konklusion
Hybrid-mode skal først bevise én ting:
- at appen kan forblive source of truth, mens shared backend langsomt kobles på.

Hvis det ikke holder, må vi ikke gå videre til login og egentlig fælles sync endnu.
