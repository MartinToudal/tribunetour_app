# Club ID Migration Plan

## Formål
Dette dokument beskriver den konkrete plan for at migrere Tribunetour fra nuværende danske klub-id'er til nye canonical ids.

Målet er:
- at gøre reference-data klar til multi-league
- at beskytte eksisterende brugerdata under migrationen
- at gøre Tyskland muligt som næste league pack uden id-kaos

Se også:
- `CLUB_ID_POLICY.md`
- `DANISH_CLUB_ID_AUDIT.md`
- `DANISH_CLUB_ID_MAPPING_DRAFT.md`

## Hvad der skal migreres
Følgende lag binder i dag på nuværende `clubId`:
- `stadiums.csv`
- `fixtures.csv`
- webens genererede reference-data
- appens og webens routes
- `visited`
- `notes`
- `reviews`
- `photos`
- `weekend plan` hvor fixtures indirekte peger på klub-id'er
- eventuelle lokale caches og fallback-filer

Det betyder:
- migrationen må ikke behandles som en ren CSV-ændring
- den er både reference-data-migration og brugerdata-migration

## Overordnet strategi
Migrationen bør ske i to spor:

### Spor A: Reference-data
- nye canonical ids indføres i reference-data
- fixtures opdateres til at pege på de nye ids
- web-artefakter regenereres

### Spor B: Brugerdata
- eksisterende brugerdata på gamle ids mappes til nye ids
- app og web skal kunne læse både gamle og nye ids i en overgang
- derefter kan legacy ids fjernes

## Anbefalet faseplan

### Fase 1: Lås mapping
Mål:
- beslutte den endelige mapping fra legacy id til canonical id

Leverance:
- godkendt version af `DANISH_CLUB_ID_MAPPING_DRAFT.md`

Output:
- én autoritativ mappingtabel

### Fase 2: Gør modellen klar
Mål:
- gøre kode og data-model klar til nye ids og shortcodes

Arbejde:
- behold `id` som canonical id
- tilføj `shortCode` som separat felt
- tilføj `countryCode`
- tilføj `leagueCode`
- forbered `leaguePack` hvis vi vil bruge det tidligt

Output:
- reference-data kan rumme både identitet og visningskode

### Fase 3: Migrér reference-data
Mål:
- flytte canonical ids ind i source-data

Arbejde:
- opdatér `stadiums.csv`
- opdatér `fixtures.csv`
- regenerér webens JSON-artefakter
- kør validatorer

Output:
- reference-data bruger kun nye canonical ids

### Fase 4: Midlertidig compatibility
Mål:
- undgå at gamle brugerdata “forsvinder” ved første launch efter migration

Arbejde:
- indfør en mapping-funktion fra legacy ids til canonical ids
- brug den ved indlæsning af lokale data
- brug den ved indlæsning af shared data, hvis gamle ids stadig findes remote
- brug den i route-lookup og fixture-lookup hvor relevant

Output:
- app og web kan stadig forstå gamle ids i en overgang

### Fase 5: Migrér brugerdata
Mål:
- flytte eksisterende brugerdata til de nye ids

Arbejde:
- migrér lokale app-data ved load
- migrér shared `visited`
- migrér shared `notes`
- migrér shared `reviews`
- migrér shared `photos`
- verificér at weekendplan stadig matcher via fixture ids

Output:
- brugerens data peger på canonical ids

### Fase 6: Cleanup
Mål:
- fjerne overgangslag når migrationen er verificeret

Arbejde:
- fjern legacy-id fallback
- fjern midlertidig alias-logik
- behold kun dokumenteret migrationstabel som historik

Output:
- systemet står på ren canonical model

## Detaljer pr. datalag

### 1. `stadiums.csv`
Skal ændres fra legacy ids til canonical ids.

Samtidig bør filen udvides med:
- `shortCode`
- `countryCode`
- evt. `leagueCode`

### 2. `fixtures.csv`
Skal opdateres så:
- `homeTeamId`
- `awayTeamId`
- `venueClubId`
alle peger på de nye canonical ids.

Fixture `id` kan i første omgang bevares, hvis relationerne opdateres korrekt.

### 3. Shared brugerdata
Risikoen her er størst, fordi disse tabeller allerede bruger `club_id` som nøgle:
- visited
- notes
- reviews
- photos

Anbefalet retning:
- lav en bevidst migrator der kan mappe gamle ids til nye
- kør den kontrolleret og idempotent
- undgå manuelle ad hoc-opdateringer direkte i produktion

### 4. Fotos
Fotos kræver særlig opmærksomhed, fordi både metadata og storage-path kan være bundet til `club_id`.

Det betyder:
- metadata-rækker i `photos` skal opdateres
- vi skal beslutte om storage-paths også skal migreres, eller om de kan blive liggende med gamle filstier midlertidigt

Anbefaling:
- lad metadata-migration komme først
- vurder storage-path-migration som separat step hvis nødvendigt

Erfaring fra den første canonical migration:
- metadata-backfill alene var ikke nok
- eksisterende fotoobjekter i `stadium-photos` lå fortsat på legacy paths som `.../vff/...` og `.../lys/...`
- app og web måtte derfor have et midlertidigt fallback-lag, som prøver både canonical og legacy storage-paths ved læsning og sletning

Praktisk konsekvens:
- photo-storage-path migration bør behandles som et separat oprydningsspor
- den må ikke køres samtidig med metadata-backfill uden ekstra verifikation
- indtil den er kørt, skal compatibility-laget blive stående

Erfaring fra den første Supabase backfill:
- den daværende live App Store-build kunne efter backfill skrive `visited`-state forkert tilbage remote
- remote feeds og shared sync skal derfor holdes bagudkompatible med den live appversion, indtil en ny release er bredt ude
- efter reference-data- og `club_id`-migrationer bør vi altid køre en tværflade sanity-runde på både live app, ny app-build og web før vi kalder migrationen stabil

### 5. Routes og lookup
Web og app bør i en overgang kunne:
- forstå gammel id i eksisterende links/data
- resolve til ny canonical id internt

Det bør være midlertidigt og dokumenteret som compatibility-lag.

## Testkrav før go
Migrationen er først klar når følgende er verificeret:

1. reference-data validerer grønt
2. web-build er grøn
3. app-build er grøn
4. fixtures peger korrekt på nye ids
5. `visited` overlever migration
6. `notes` overlever migration
7. `reviews` overlever migration
8. `photos` overlever migration
9. detailruter og opslag virker stadig
10. regressionstest opdateres til nye ids

## No-go kriterier
Migrationen må ikke køres hvis:
- mappingen ikke er endeligt godkendt
- fixtures stadig peger på gamle ids
- der ikke findes en plan for shared brugerdata
- vi ikke kan teste både app og web på samme nye id-sæt

## Anbefalet konkret rækkefølge
1. Lås mapping-dokumentet
2. Tilføj nye metadatafelter til reference-data-modellen
3. Indfør temporary legacy-id resolver i app og web
4. Migrér `stadiums.csv`
5. Migrér `fixtures.csv`
6. Generér web-artefakter
7. Test reference-data grønt
8. Migrér shared brugerdata
9. Test tværflade grønt
10. Først derefter åbne første tyske league pack

## Konklusion
Næste rigtige tekniske step før Tyskland er ikke import af Bundesliga-data.

Det er at gøre den danske model klar til multi-league ved at:
- låse canonical ids
- migrere reference-data
- beskytte brugerdata
- og kun derefter åbne næste landepack
