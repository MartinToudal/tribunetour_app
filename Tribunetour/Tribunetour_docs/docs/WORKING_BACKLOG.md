# Working Backlog

Senest opdateret: 2026-08-28

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
  - Fjern premium-copy, gates og anmodningsflow fra brugerfladen.
  - Gør alle stadionlande tilgængelige uden login.
  - Indlæs kun Danmark ved opstart.
  - Indlæs valgt internationalt land efter brugerhandling og cache det lokalt.
  - Accept: gæst og logget ind har samme landescope, uden at opstarten indlæser Europa.

- **Fase 3: Kun danske kampe**
  - Fjern internationale fixtures fra produktet.
  - Gennemfør API-prøve for danske rækker.
  - Indfør centralt, versionsstyret dansk fixture-feed med cache og fallback.
  - Fjern dublerede kamp-ID'er i feedets produktionsled; det offentlige feed havde 17 identiske dubletter ved kontrollen 2026-08-28.
  - Accept: `Kampe` viser kun Danmark og overlever fejl hos datakilden.

- **Fase 4: Danmark-først Min tur og achievements**
  - Dansk statistik og progression er standard.
  - International statistik og achievements flyttes til aktivt tilvalg.
  - Accept: internationale tal blandes ikke ind i dansk hovedprogression.

- **Fase 5: Afvikl web som produkt**
  - Kortlæg og flyt nødvendige jobs før offentlig webfunktionalitet fjernes.
  - Bevar login/sync i Supabase.
  - Accept: ingen app-, sync- eller fixturefunktion afhænger af webproduktet.

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
