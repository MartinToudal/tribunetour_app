# Current State

Senest opdateret: 2026-04-14

Dette dokument er den hurtigste indgang til den nuværende sandhed i Tribunetour.

Hvis noget andet dokument siger noget lidt andet, så er dette dokument den praktiske reference først.

## Produktet lige nu

Tribunetour er ét produkt med to flader:
- iOS-app
- web på `tribunetour.dk`

De deler nu:
- login-retning via Supabase
- personlig brugerdata på tværs af flader for de vigtigste områder
- samme reference-data-kontrakt
- samme grundidé om `Stadions`, `Kampe`, `Plan` og `Min tur`

## Hvad der er delt mellem app og web

Disse ting er nu bygget som fælles brugeroplevelse eller fælles datamodeller:
- login
- visited-status
- noter
- reviews
- billeder
- weekend-plan
- entitlement-baseret adgang til premium league packs

## Hvad der ikke er fuldt konsolideret endnu

- appen bærer stadig noget overgangslogik fra ældre lokale/CloudKit-spor
- reference-data kommer endnu ikke fuldt fra backend for alle lande
- nye lande kræver stadig kode/dataarbejde og ikke kun backend-oprettelse
- tværflade-sync er fokus-/aktiveringsbaseret og ikke realtime

## Premium og league packs

Den nuværende model er:
- `core_denmark` er grundpakken
- `germany_top_3` er første premium-pakke

Adgang styres centralt i Supabase-tabellen:
- `public.user_league_pack_access`

Pakken bliver synlig når brugeren har adgang til den konkrete `pack_key`.

Næste anbefalede udviklingstrin er:
- støtte både `premium_full`
- og adgang til enkelte landepakker

## Hjemland og scope

Appen har nu:
- valg af hjemland
- hjemland som default scope når appen åbner
- mere konsistent landefilter på tværs af `Stadions`, `Kampe`, `Plan` og `Min tur`

## Liga-sortering

Tribunetour bruger nu en mere bevidst pyramide-sortering pr. land.

Eksempler:
- Danmark: `Superliga`, `1. division`, `2. division`, `3. division`
- Tyskland: `Bundesliga`, `2. Bundesliga`, `3. Liga`

Det er retningen fremover:
- sortering efter pyramiden for det enkelte land
- ikke primært alfabetisk

## Achievements

`Min tur` skelner nu mellem:
- `Grundachievements`
- `Premium achievements`

Tanken er:
- grundpakken skal stadig give mening selv hvis flere lande er aktive
- premium-indhold skal kunne give ekstra mål uden at ødelægge den grundlæggende progression

## Vigtigste filer lige nu

App:
- `Tribunetour/ContentView.swift`
- `Tribunetour/AppState.swift`
- `Tribunetour/CSVClubImporter.swift`
- `Tribunetour/MatchesView.swift`
- `Tribunetour/WeekendPlannerView.swift`
- `Tribunetour/StatsView.swift`
- `Tribunetour/StadiumDetailView.swift`

Web:
- `Website repo/README.md`
- `Website repo/app/(site)/_lib/referenceData.ts`
- `Website repo/app/(site)/_lib/visitedRepository.ts`
- `Website repo/app/(site)/_hooks/useVisitedModel.ts`

Supabase:
- `Website repo/supabase/user_league_pack_access.sql`

## Hvor man skal starte som læser

1. dette dokument
2. `PRODUCT_AND_CODE_WALKTHROUGH.txt`
3. `INTEGRATION_STATUS.md`
4. `GERMANY_LEAGUE_PACK.md`

## Kort konklusion

Tribunetour er ikke længere to separate spor.

Det er nu reelt ét produkt, hvor:
- appen stadig er den mest modne flade
- web er blevet en rigtig produktflade
- premium league packs er introduceret i første version
- dokumentationen har brug for én tydelig nutids-reference
