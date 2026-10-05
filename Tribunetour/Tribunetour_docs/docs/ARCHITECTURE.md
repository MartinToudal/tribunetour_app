# Architecture

Senest opdateret: 2026-10-05

Dette dokument beskriver den faktiske arkitektur, som den er nu. Det er ikke en beskrivelse af den ønskede fremtid.

## Systemlandskab

Tribunetour består i praksis af tre tekniske områder:

1. **iOS-app-repositoriet**
   - SwiftUI-brugerflade, navigation og lokal state.
   - Bundlet stadion-, klub- og landepakkedata.
   - Remote indlæsning af danske fixtures med cache og lokal fallback.
   - Login, brugerdata og sync-klienter.

2. **Web-/driftsrepositoriet**
   - Intern Klubtjek- og driftsflade.
   - Generering og validering af reference-dataartefakter.
   - Daily Fixture Check, Fixture Audit og mailrapporter.
   - GitHub Actions og Vercel-deploy.

3. **Supabase**
   - Auth og centrale brugerdatafunktioner.
   - Eventuel historik for Klubtjek, ændringsforslag og godkendelser.
   - Ikke en nødvendig runtime-kilde for klub- og stadion-reference-data.

## Faktisk dataflow

### Klubber og stadions i iOS

`AppState` indlæser klubber og stadions fra appens bundle:

```text
stadiums.csv
  -> CSVClubImporter
  -> AppState.clubs / clubById
  -> Stadions, Min tur, statistik og detailvisninger
```

Internationalt indhold indlæses som landepakker efter brugerens valg. Det er altså ikke et live-opslag fra Supabase.

### Danske fixtures i iOS

```text
web-publiceret remote fixture-feed
  -> RemoteFixturesProvider
  -> validering, dansk scope, sæsonfilter og deduplikering
  -> lokal fixture-cache
  -> Kampe
```

Hvis remote-feedet ikke kan bruges:

```text
remote-feed
  -> cached remote data
  -> fixtures_denmark.csv
```

Appen viser kun fixtures, hvor hjemmehold, udehold og stadion kan matches til den indlæste danske klubidentitet.

### Web-reference-data og fixture-drift

Web-repositoriet har egne JSON-artefakter og scripts til generering, audits og publicering. GitHub Actions kan automatisk opdatere fixture-data og publicere det feed, som appen læser.

```text
web data/scripts/workflows
  -> genererede JSON-filer
  -> Vercel/public feed
  -> iOS RemoteFixturesProvider
```

Det betyder, at web-repositoriet i dag stadig er produktkritisk for danske fixtures, selv om web ikke længere skal være en brugervendt produktflade.

### Klubtjek, hvis det fortsat anvendes

Klubtjek er et eksisterende adminværktøj, men er ikke længere den anbefalede kernearbejdsgang for reference-data. Den foretrukne arbejdsgang er halvårlig gennemgang og rettelse af CSV-filer efterfulgt af samlet validering og app-release.

## Source of truth pr. domæne

| Domæne | Faktisk autoritativ kilde nu | Vigtig begrænsning |
|---|---|---|
| App-UI | iOS-repositoriet | App og web har separate UI-kodebaser |
| Klub/stadion i iOS | Versionerede CSV-filer og landepakker i app-repositoriet | Ændringer udgives samlet i app-release |
| Danske fixtures | Senest godkendte web-feed med app-cache/fallback | Afhænger fortsat af web-repo og deploy |
| Klubtjek | Supabase reviews, proposals og overrides, hvis værktøjet bruges | Sekundært historik-/adminspor |
| Visited, noter, fotos og reviews | Brugerdata via eksisterende sync-spor | Reference-data og brugerdata er forskellige lag |
| Fixture-audit | Web-scripts og GitHub Actions | Skal fortsat afgrænses til dansk scope |
| Backlog | `WORKING_BACKLOG.md` i app-repositoriet | Admin-UI er ikke den autoritative backlog endnu |

## Hvor diskrepanser kan opstå

1. En koordinat eller række ændres i Supabase, men ikke i appens bundle.
2. En landepakke indeholder et andet klub-ID eller en ældre række end den centrale model.
3. Web-feedet ændres, men appen viser cache eller lokal fallback.
4. App og web genererer hver sin visning af samme reference-data.
5. En fixture peger på et hold-ID, som ikke findes i appens aktuelt indlæste scope.
6. Historisk rækketilhør blandes sammen med aktiv række.

## Første målarkitektur

Vi skal ikke starte med en blind totalomskrivning. Første arkitekturmål er:

1. Én canonical, versionsstyret CSV-struktur for klub, stadion, aktiv række, sæson og historik.
2. Stabilt klub-ID på tværs af app, web og brugerdata.
3. En dokumenteret halvårlig kontrol- og releaseproces for reference-data.
4. Web bruges kun til nødvendige fixtures, drift og eventuelle historiske adminværktøjer.
5. Supabase bruges til login, sync og brugerdata, ikke som skjult alternativ til CSV-kilden.
6. En senere central distribution kan tilføjes, hvis den halvårlige proces ikke længere er tilstrækkelig.

## Næste arkitekturleverance

Før større nye features skal vi færdiggøre Story 10.2 og Story 3.6:

- dokumentér den samlede CSV-baserede canonical model
- fastlæg ID-, sæson- og historikregler
- definér kontrolfil, validering og releaseproces for en rækkevis gennemgang
- test processen på én dansk række fra CSV til app-release

Først når dette fungerer, har vi et sikkert grundlag for at udvide med flere lande, lavere danske niveauer eller rige stadionprofiler.
