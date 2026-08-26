# Current State

Senest opdateret: 2026-08-26

Dette dokument er den hurtigste indgang til produktets nuværende retning i Tribunetour.

Hvis du har brug for driftssandhed om repoer, source of truth og leveranceflow, så brug i stedet:
- `[SYSTEM_OWNERSHIP_AND_OPERATING_MODEL.md](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/Tribunetour_docs/docs/SYSTEM_OWNERSHIP_AND_OPERATING_MODEL.md)`

Hvis noget andet dokument siger noget lidt andet, så gælder:
- produktretning: dette dokument
- drifts- og systemejerskab: `SYSTEM_OWNERSHIP_AND_OPERATING_MODEL.md`

## Ny låst produktretning

Tribunetour omlægges til et Danmark-først iOS-produkt.

De styrende beslutninger og migrationsfaser står i:
- `[DENMARK_FIRST_PRODUCT_RESET.md](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/Tribunetour_docs/docs/DENMARK_FIRST_PRODUCT_RESET.md)`

Kort fortalt:
- iOS bliver eneste fremtidige produktflade
- login og sync bevares
- premium udfases, og alle stadionlande bliver gratis
- kun Danmark skal have kampprogram
- Danmark indlæses ved opstart, mens andre lande indlæses efter valg
- `Plan` fjernes
- `Min tur` og achievements bliver Danmark-først med internationalt indhold som tilvalg

## Produktet før migrationen

Den nuværende kodebase er stadig ét produkt med to flader:
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

## Premium og league packs under udfasning

Den tekniske model er stadig:
- `core_denmark` er grundpakken
- `germany_top_3` er første premium-pakke

Adgang styres centralt i Supabase-tabellen:
- `public.user_league_pack_access`

Pakken bliver synlig når brugeren har adgang til den konkrete `pack_key`.

Denne model skal ikke udvides. Den udfases kontrolleret, når land-on-demand-indlæsningen er på plads.

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

Tribunetour skal opleves som ét produkt, men er i drift stadig bygget over flere tekniske spor.

Det betyder i praksis:
- brugeren skal møde én samlet løsning
- men vi arbejder stadig med særskilt app-repo, web-repo og delt backend/dataflow

Det er derfor ikke tilstrækkeligt at sige, at noget er “på plads”, uden også at sige:
- i hvilket repo
- på hvilken branch
- om det er pushed
- om det er deployed
- om det kræver ny app-build

Produktretningen er nu:
- Danmark er kerneproduktet
- iOS er den eneste fremtidige produktflade
- webprodukt og premium udfases
- login/sync bevares
- internationalt indhold bliver et gratis stadionarkiv, som indlæses efter behov
