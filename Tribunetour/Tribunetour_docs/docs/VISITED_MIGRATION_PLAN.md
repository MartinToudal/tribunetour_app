# Visited Migration Plan

## Formål
Dette dokument beskriver den konkrete migrationsplan fra den nuværende web-first `visits`-model til en fælles `visited`-model, der kan bruges af både web og app.

Målet er at:
- bevare det der allerede virker på web
- minimere risiko for regressioner
- skabe et klart mellemtrin før appen kobles på
- undgå at UI-laget bliver ved med at kende direkte til tabelstruktur

## Nuværende web-implementering

### Hvad der findes i dag
Web bruger i dag:
- Supabase auth via magic link
- direkte læsning fra tabel `visits`
- direkte skrivning til tabel `visits`
- klient-hooken `useVisitedModel` som fælles indgang til visited-state i UI

Aktuel semantik:
- en række i `visits` betyder `visited = true`
- ingen række betyder `visited = false`
- `delete` bruges som “marker som ubesøgt”

### Begrænsninger i den nuværende model
Den nuværende model kan ikke bære:
- `visitedDate`
- `source`
- `createdAt` og `updatedAt`
- konfliktregler
- et tydeligt backend-contract
- genbrug mellem web og app uden ekstra oversættelse

## Målmodel
Target-modellen er defineret i:
- `VISITED_SHARED_MODEL.md`
- `VISITED_BACKEND_CONTRACT.md`

Første fælles record skal have disse felter:
- `userId`
- `clubId`
- `visited`
- `visitedDate`
- `createdAt`
- `updatedAt`
- `source`

Bemærk:
- klienten bør ikke eje `userId` som sandhed
- klienten bør ikke kende den fysiske tabelstruktur direkte

## Designprincip for migrationen


## Kildehierarki i overgangsperioden

I migrationsperioden gælder denne regel:
- appen er source of truth for eksisterende visited-data
- web er sekundær klient, indtil egentlig app/shared-konvergens er gennemført

Det betyder:
- hvis en bruger allerede har korrekt besøgsstatus i appen, skal den status anses som den rigtige
- web må gerne skrive nye ændringer, men brugeren skal advares om, at appen stadig er den primære sandhed i overgangsfasen
- senere migrering eller sync-logik skal favorisere appens allerede etablerede data frem for at lade web overskrive dem blindt

Praktisk produktregel:
- hvis web og app viser forskellig besøgsstatus i overgangsperioden, bør brugeren rette i appen først

## Første login i appen: bootstrap fra app til shared backend

Når en bruger logger ind i appen første gang efter shared auth er indført, skal vi ikke lave en løs merge mellem web og app.

Vi skal i stedet lave en kontrolleret bootstrap.

### Princip
- bootstrap sker kun én gang pr. bruger
- appens lokale visited-snapshot er den autoritative kilde i bootstrap-øjeblikket
- backendens eksisterende web-status må ikke blandes automatisk ind i resultatet
- når bootstrap er gennemført, skifter brugeren over i normal shared sync

### Hvorfor ikke automatisk merge
Hvis vi blindt merger app og web, mister vi den forretningsregel der allerede er valgt:
- appen er sandheden for eksisterende brugerdata

Eksempel:
- web har `13` besøgt
- app har `3` besøgt

Hvis vi merger disse til `13`, har appen ikke været source of truth.

Hvis appen skal være sandheden, skal bootstrap-resultatet derfor være:
- shared backend = appens snapshot

### Bootstrap-flow
1. bruger logger ind i appen
2. appen spørger backend om brugeren allerede er bootstrap-migreret
3. hvis `nej`, vises en kort migrationsadvarsel
4. brugeren bekræfter, at appens registreringer skal bruges som udgangspunkt
5. appen uploader et komplet visited-snapshot
6. backend markerer bootstrap som gennemført for brugeren
7. derefter bruges almindelig shared sync på tværs af app og web

### Vigtigt: komplet snapshot, ikke delvis write
Bootstrap må ikke kun være:
- “skriv alle appens `visited = true`”

Det er utilstrækkeligt, fordi gamle web-registreringer ellers bliver liggende.

Bootstrap skal i stedet skrive den fulde sandhed:
- `visited = true` for alle stadions appen har markeret som besøgt
- `visited = false` for alle stadions der tidligere stod som besøgt i shared backend, men som ikke findes som besøgt i appen

Det er den eneste måde at sikre, at shared backend faktisk bliver et billede af appens sandhed.

### Efter bootstrap
Når bootstrap er gennemført:
- app og web læser samme shared model
- app og web skriver samme shared model
- særreglen “appen er sandheden” ophører for den konkrete bruger
- fremtidige ændringer håndteres som normal sync, ikke migration

### Besluttet steady-state efter bootstrap
Dette er den låste beslutning:
- shared backend er autoritativ for `visited`
- app og web er klienter mod samme sandhed
- CloudKit må gerne eksistere som overgangslag, men ikke som konkurrerende source of truth

Praktisk betyder det:
- hvis app og web afviger efter gennemført bootstrap, er det et sync- eller klientproblem
- det er ikke en legitim produkttilstand, at appen bagefter stadig “vinder” som særregel
- produktcopy skal gradvist væk fra formuleringen om, at appen er den sikre kilde, når brugeren allerede er i steady-state

### Brugeroplevelse
Første login i appen skal have en kort besked i stil med:
- “Første gang du logger ind, bruger vi dine registreringer i appen som udgangspunkt for din fælles visited-status.”
- “Eventuelle tidligere web-registreringer bliver erstattet af appens nuværende data.”

Denne besked skal kun vises én gang pr. bruger.

Vi bruger en trinvis migration.

Det betyder:
- ingen stor omskrivning i ét hug
- ingen samtidig migration af app og web
- ingen breaking ændring i UI-kontrakter, før repository-laget er på plads

## Fase 0: Stabiliser nuværende web-retning

### Mål
Frys den nuværende virkende UI-adfærd, så vi migrerer under et stabilt UI-lag.

### Status
Denne fase er i praksis gennemført:
- `Stadions`, `Kampe`, `Kort`, `Min tur`, stadiondetaljer og kampdetaljer læser samme visited-hook
- webens mobil- og state-modeller er blevet strammet op

## Fase 1: Indfør et repository-lag

### Mål
Flyt databasekendskab ud af `useVisitedModel`.

### Hvorfor
Det er den vigtigste afkobling.
Når UI-hooken ikke længere kender tabelnavn og felter direkte, kan vi ændre backend-modellen uden at rive alle komponenter op.

### Konkrete ændringer
Tilføj et nyt lag, fx:
- `app/(site)/_lib/visitedRepository.ts`

Dette lag skal eje:
- `getVisitedForCurrentUser()`
- `setVisited(clubId, visited)`
- senere også `setVisited(clubId, visited, visitedDate, source)`

### Krav
`useVisitedModel` må efter denne fase ikke længere selv kalde:
- `.from('visits')`
- `.insert(...)`
- `.delete(...)`

## Fase 2: Udvid datamodellen uden at bryde web

### Mål
Gør backend-modellen i stand til at repræsentere shared target-modelen.

### Anbefalet retning
I stedet for ren `insert/delete` skal modellen kunne gemme én record pr. `(user, club)`.

Anbefalet fysisk retning:
- ny tabel `visited`
- unik constraint på `(user_id, club_id)`

Anbefalede felter:
- `user_id`
- `club_id`
- `visited`
- `visited_date`
- `source`
- `created_at`
- `updated_at`

### Hvorfor ny tabel i stedet for at mutere `visits`
Ny tabel er renere fordi:
- semantikken bliver tydelig
- vi undgår at overbelaste en binær tabel med ny betydning
- migration og rollback bliver lettere at styre

## Fase 3: Læs gammel og ny model parallelt i overgangsperiode

### Mål
Undgå hard cutover mens data flyttes.

### Midlertidig strategi
Repository-laget kan midlertidigt:
1. prøve at læse fra `visited`
2. falde tilbage til `visits`, hvis `visited` endnu ikke er etableret eller tom

Skrivning bør i overgangsfasen enten:
- kun gå til `visited`
eller
- gå til begge tabeller i en kort overgangsperiode

### Anbefaling
Skriv kun til `visited`, når tabellen er klar.
Hold `visits` som read-only fallback i kort tid, og fjern den derefter.

Det er enklere og mindre fejlpræget end dual-write i længere tid.

## Fase 4: Gør write-semantikken kontraktstyret

### Mål
Erstat “insert/delete = state” med rigtig state-opdatering.

### Ny write-adfærd
`setVisited(clubId, visited)` skal mappe til:
- upsert af record for `(user_id, club_id)`
- `visited = true/false`
- ved `true`: sæt `visited_date` hvis relevant
- ved `false`: bevar record eller nulstil status efter valgt politik

### Anbefalet politik i første iteration
Brug soft state i stedet for delete.

Det betyder:
- recorden bliver liggende
- `visited` skifter mellem `true` og `false`
- `updated_at` ændres

Fordele:
- bedre sporbarhed
- bedre for senere sync
- lettere konfliktløsning

## Fase 5: Tilføj `visitedDate` og `source`

### Mål
Få modellen op på shared target-niveau.

### Web i første iteration
Web kan begynde simpelt:
- `visitedDate = null` eller automatisk current date ved første markering
- `source = 'web'`

### Senere app-retning
Når appen kobles på, kan appen skrive:
- `source = 'ios'`
- reel `visitedDate` fra brugerens handling eller eksisterende lokale data

## Fase 6: Ryd gamle kald og legacy-filer op

### Mål
Fjerne forvirrende rester og reducere teknisk gæld.

### Kandidater til oprydning
Filer der ligner gamle eller parallelle spor:
- `Website repo/MapView.js`
- `Website repo/components/MapView.js`
- `Website repo/lib/visited.js`

Disse bør vurderes og sandsynligvis fjernes, hvis de ikke længere bruges.

## Fase 7: App-kobling

### Mål
Lad appen læse og skrive samme første fælles visited-model.

### Ikke nu
Denne fase skal ikke tages, mens vi holder appen stabil.

### Senere arbejde
Når appen åbnes igen for større ændringer:
- indfør samme auth-retning eller et kompatibelt identitetslag
- tilføj et app-side repository for shared visited-model
- migrér eller spejl eksisterende lokale/CloudKit-data gradvist

## Konkret filpåvirkning på web

### Første implementeringsbølge
Disse filer skal ændres først:
- `app/(site)/_hooks/useVisitedModel.ts`
- ny `app/(site)/_lib/visitedRepository.ts`

### Anden bølge
Disse filer bør kun ændres, hvis UI-kontrakten ændrer sig:
- `app/(site)/_components/StadiumList.tsx`
- `app/(site)/_components/MatchesList.tsx`
- `app/my/page.tsx`
- `app/stadiums/[id]/StadiumDetailClient.tsx`
- `app/matches/[id]/MatchDetailClient.tsx`
- `app/(site)/_components/MapView.tsx`

Målet er at holde UI-filerne næsten urørte.

## Foreslået implementeringsrækkefølge

1. Opret `visitedRepository.ts`
2. Flyt nuværende `visits`-kald fra `useVisitedModel` ind i repository
3. Verificér at web stadig opfører sig identisk
4. Definér fysisk `visited`-tabel i backend
5. Opdater repository til at læse/skrive ny model
6. Hold fallback-læsning fra `visits` kortvarigt
7. Fjern fallback når data er migreret
8. Planlæg app-side integration som separat fase

## Risikoanalyse

### Lav risiko
- introduktion af repository-lag uden ændring af UI-kontrakt
- read-fallback i overgangsperiode

### Mellem risiko
- ny tabel og datamigrering
- ændring fra delete-baseret til state-baseret write-model

### Høj risiko
- samtidig migration af app og web
- ændring af auth, dataformat og UI-flow i samme iteration

## Anbefalet næste konkrete arbejde
Næste implementering bør være:
- oprette `visitedRepository.ts`
- omskrive `useVisitedModel.ts` til at bruge repository-laget
- uden at ændre brugeroplevelsen

Det er den mindste mulige ændring med størst arkitektonisk effekt.
