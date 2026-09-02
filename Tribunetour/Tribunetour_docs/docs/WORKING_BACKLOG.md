# Working Backlog

Senest opdateret: 2026-09-02

Dette dokument er den operative backlog.

Det er her vi samler:
- det der aktivt blokerer drift
- det der aktivt skaber forskel mellem app og web
- det der aktivt truer arkitektur eller produktkvalitet

Hvis et punkt er vigtigt i daglig drift, skal det stå her før det står andre steder.

## Aktiv produktretning

Styrende dokument:
- `[DENMARK_FIRST_PRODUCT_RESET.md](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/Tribunetour_docs/docs/DENMARK_FIRST_PRODUCT_RESET.md)`

Låste beslutninger:
- iOS er den fremtidige produktflade
- Danmark er kerneproduktet
- login/sync bevares
- premium udfases
- alle lande bliver gratis
- kun Danmark har kampprogram
- internationale lande indlæses efter valg og indeholder kun stadions
- `Plan` fjernes

## P0 – Danmark-først migration

- **Fase 1: Enkel navigation**
  - [x] Fjern `Plan` fra fanebaren.
  - [x] Behold plandata og synckode midlertidigt for sikker rollback.
  - [x] Gør fixture-indlæsningen robust over for dublerede kamp-ID'er.
  - [x] Accept: tre hovedfaner og grønt iOS-build.
  - Status: gennemført lokalt. Crash-sikring og regressionstest verificeret 2026-08-28.

- **Fase 2: Gratis adgang og land-on-demand**
  - [x] Fjern premium-copy, gates og anmodningsflow fra brugerfladen.
  - [x] Gør alle stadionlande tilgængelige uden login.
  - [x] Indlæs kun Danmark ved opstart.
  - [x] Indlæs valgt internationalt land efter brugerhandling og behold det i sessionscache.
  - [x] Accept: gæst og logget ind har samme landescope, uden at opstarten indlæser Europa.
  - Status: gennemført lokalt og regressionssikret 2026-08-29. Landvælgeren bruger en dedikeret navigationsskærm, kort og kontroller måles som separate responsive rækker, og et tidligt landeskift kan ikke længere overskrives af den indledende Danmark-load. Build og funktionstest er grønne. Portrait-geometrien er automatisk verificeret ved 390, 402 og 440 punkters bredde.
  - Release-checkpoint: TestFlight-kandidat `1.0.3 (23)` er klargjort. Fase 3 starter først, når buildet er uploadet og accepteret som fase 2-baseline.

- **Fase 3: Kun danske kampe**
  - [x] Fjern internationale fixtures fra produktet og fra den lokale fallback.
  - [x] Fjern landevalg fra `Kampe` og gør dansk scope synligt.
  - [x] Gennemfør API-prøve for danske rækker.
  - [x] Indfør validering, deduplikering, senest-kendt-god cache og dansk bundle-fallback i appen.
  - [x] Publicer et separat, versionsstyret dansk remote-feed.
  - [x] Fjern dublerede kamp-ID'er i feedets produktionsled; de 17 identiske dubletter er håndteret strukturelt.
  - [x] Accept, app: `Kampe` viser kun Danmark og overlever fejl hos datakilden.
  - [x] Accept, drift: appen modtager et rent dansk feed uden afhængighed af det europæiske feed.
  - Status: fase 3 er afsluttet 2026-08-30. API-prøven fandt ingen gratis, lovlig og komplet kilde til dansk niveau 1-4, så den eksisterende generator-kæde er bevaret som overgang. Det nye danske feed er live, appkoblingen er testet, og en ny TestFlight-build er næste leverancetrin.

- **Fase 4: Danmark-først Min tur og achievements**
  - [x] Dansk statistik, progression og anbefalinger er standard i `Min tur`.
  - [x] International statistik er flyttet til et eksplicit scopevalg.
  - [x] Noter, anmeldelser og billeder følger det valgte scope.
  - [x] Achievements og næste mål beregnes ud fra det aktive scope, uden at internationalt scope ændrer dansk scope.
  - [x] Accept: internationale tal blandes ikke ind i dansk hovedprogression.
  - Status: første leverance gennemført og UI-/unit-testet 2026-09-01. Danmark er standard; internationalt indhold kan åbnes via `Danmark`/`Internationalt` i `Min tur`.
  - [ ] Gennemgå achievement-navne, milepæle og rækkefølge med product owner før næste udbygning.

- **Fase 5: Afvikl web som produkt**
  - Kortlæg og flyt nødvendige jobs før offentlig webfunktionalitet fjernes.
  - Bevar login/sync i Supabase.
  - Accept: ingen app-, sync- eller fixturefunktion afhænger af webproduktet.

- **Fase 6: API-baseret dansk kampprogram**
  - [ ] Opret en isoleret API-Football prøve med server-side API-nøgle.
  - [ ] Verificer dækning for de danske rækker, vi faktisk viser, inklusive 2026/27-sæsonen.
  - [ ] Sammenlign hold-id'er, kamp-id'er, kickoff, flytninger, aflysninger og manglende kampe med det nuværende feed.
  - [ ] Afklar brugs- og publiceringsrettigheder for appens visning af data.
  - [ ] Mål request-forbruget mod gratisplanens 100 requests pr. dag og dokumenter om en central backend-sync er tilstrækkelig.
  - [ ] Indfør API-Football som udskiftelig backend-kilde bag det eksisterende danske feed-/cachelag, ikke som direkte appkald.
  - [ ] Kør API-feed og nuværende feed parallelt i en observationsperiode.
  - [ ] Udfas dagligt fixture-check og fuld fixture-audit først efter stabil observationsperiode; behold alarmer ved fetch-fejl og schemaændringer.
  - Accept: dansk kampprogram opdateres automatisk, kan falde tilbage til seneste valide version, og kilden kan udskiftes uden appændring.
  - Status: ny kandidat identificeret 2026-09-02. API-Football angiver dansk dækning og 100 gratis requests pr. dag, men den tekniske, juridiske og sæsonmæssige validering mangler.

## P0 – Drift og arkitektur

- **Systemoverblik og source of truth**
  - Vi har to produktkritiske repoer i samme arbejdsmappe: app og web.
  - Vi mangler én fast driftsreference for ejerskab, dataflow og leveranceflow.
  - Løst delvist via:
    - `[SYSTEM_OWNERSHIP_AND_OPERATING_MODEL.md](/Users/martintoudal/Documents/Tribunetour/Tribunetour/Tribunetour/Tribunetour_docs/docs/SYSTEM_OWNERSHIP_AND_OPERATING_MODEL.md)`
  - Åbent indtil vi også har:
    - en fast ændringsprotokol indbygget i backlog/process
    - et mere samlet dataflow mellem app og web

- **Én app-sandhed for stadions og danske fixtures**
  - Appens danske kernedata og internationale landepakker skal have tydelige, separate ejere.
  - Web-repoets datajobs er overgangsdrift og må ikke forveksles med den fremtidige produktflade.

- **Driftssikker fixture-pipeline**
  - Daily check og audits skal være stabile, forklarlige og lette at fejlfinde.
  - Fejl skal forstås som driftssignaler, ikke bare dataafvigelser.
  - Fremtidig retning: erstattes af API-feedets validering og alarmer, men først efter parallel drift og dokumenteret stabilitet.

## P0 – Kendte aktive driftsproblemer

- **Litauen – II Lyga A/B**
  - Tidligere `fetch-failed` skyldtes LFF-parseren.
  - Parserfix findes lokalt, men er ikke sikkert integreret ovenpå den aktuelle web-hovedlinje endnu.
  - Status:
    - root cause er identificeret
    - endelig ren integration på web-hovedlinjen mangler stadig

- **Repo-disciplin mellem app og web**
  - Vi skal undgå igen at sige “alt lokalt er på plads”, når kun ét repo er grønt.

## P1 – Datakvalitet og kontrol

- **Dedikeret side til manuel klubkontrol**
  - Brug for en intern flade med:
    - klub korrekt
    - kampprogram korrekt
    - lokation korrekt
    - historik for seneste kontrol
  - Åben beslutning: internt iOS-område eller separat driftsværktøj.

## P1 – Data og sæsonskifte

- **API-Football kandidat skal valideres før kildevalg**
  - Coverage viser danske Superliga, 1. Division, 2. Division og 3. Division.
  - Gratisplanen angiver 100 requests pr. dag og fixtures-endpoint.
  - API'et må ikke kaldes direkte fra appen; API-nøglen skal blive på backend.
  - Kilde og rettigheder er ikke godkendt til produktion endnu.

- **Serie C og Portugal niveau 3 skal holdes ajour**
  - Endelige gruppestrukturer og sæsonskifter skal løbende opdateres.

- **Ukendte holdnavne i daily checks skal reduceres systematisk**
  - Vi skal løbende rydde alias- og turneringsstøj væk.

## P2 – Strukturelle forbedringer

- **Systemkort**
  - Vi mangler et simpelt diagram over:
    - app
    - web
    - Supabase
    - fixture-pipeline
    - release/deploy-flow

- **Én genereringskæde for reference-data**
  - På sigt bør app og web konsumere samme genererede sandhed.
