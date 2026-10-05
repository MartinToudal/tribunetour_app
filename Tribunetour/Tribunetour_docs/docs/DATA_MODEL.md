# Data Model

Senest opdateret: 2026-10-05

Dette dokument beskriver de vigtigste dataområder og deres nuværende ejerskab. Reference-data og brugerdata er forskellige lag.

## Reference-data

### Club / stadium record

Appens bundlet CSV- og landepakkedata bruger i praksis én klub/stadion-post med mindst:

- `id`: stabil klubnøgle
- `name`: klubnavn
- `team`: stadionets eller klubbens visningsnavn
- `league`: aktiv række i den aktuelle pakke
- `city`: by
- `lat`, `lon`: koordinater
- land, niveau, sæson og eventuelle historiske medlemskaber efter landepakkens format

Den stabile `id` skal genbruges, når stadionnavn, koordinater eller aktiv række ændres. Fixtures og besøgsdata må ikke miste deres binding ved en almindelig datarettelse.

### Fixture

En fixture har mindst:

- `id`
- `kickoff`
- `round`
- `homeTeamId`
- `awayTeamId`
- `venueClubId`
- `status`
- eventuelt `homeScore`, `awayScore`, `competitionId` og `seasonId`

`homeTeamId`, `awayTeamId` og `venueClubId` skal kunne slås op i samme klub-ID-familie som stadiondata.

## Nuværende reference-dataflow

| Område | Indlæsning i appen | Nuværende begrænsning |
|---|---|---|
| Klubber/stadions | Versionerede `stadiums.csv` og landepakker | Rettelser udgives samlet i en ny app-version |
| Danske fixtures | Remote JSON, derefter cached remote og `fixtures_denmark.csv` | Remote-feedet publiceres fra web/driftsrepositoriet |
| Web-reference-data | Genererede JSON-filer og webens loader-lag | App og web har stadig forskellige artefakter |
| Sæsonhistorik | CSV-landepakker og historiske medlemskaber | Modellen er ikke samlet i én central tabel endnu |

## Brugerdata

Brugerdata skal ikke overskrives af reference-dataopdateringer. Områderne omfatter blandt andet:

- visited-status og visited-dato
- noter
- anmeldelser
- billeder og billedmetadata
- login og sync-relaterede brugeroplysninger

De eksisterende sync-spor kan være forskellige teknisk. Det skal afklares samlet i arkitekturfornyelsen, men reference-data må ikke ændre brugerens historik utilsigtet.

## Klubtjek-data

Klubtjek bruger centralt:

- kontrol/review
- kontrolstatus
- ændringsforslag
- gammel og ny værdi
- godkendelsesstatus
- eventuelle stadium-overrides
- bruger og tidspunkt

Nuværende flow:

```text
adminkontrol
  -> review
  -> ændringsforslag
  -> eksplicit godkendelse
  -> central stadium-data eller override
```

Klubtjek er ikke længere den planlagte primære distributionsvej. Hvis værktøjet bruges, er det et sekundært admin- og historikspor. Den primære vej er redaktionel CSV-gennemgang og samlet app-release.

## Source-of-truth-regler

Indtil en eventuel fremtidig central distribution bliver relevant, skal vi skelne mellem:

1. **Godkendt indhold:** den senest godkendte reference-data i versionsstyrede CSV-filer.
2. **Distribueret artefakt:** appens bundlede CSV og genererede web-artefakter.
3. **Lokal fallback:** cached remote-data for fixtures, hvor det er relevant.

Lokal fallback er sikkerhedsnet, ikke et alternativt redigeringssted.

## Kritiske integritetsregler

- En klub-ID må ikke skifte ved en koordinat- eller rækkekorrektion.
- En aktiv række skal have land, niveau og sæson, hvor modellen understøtter det.
- Historisk rækketilhør må ikke overskrive aktiv række.
- Fixtures må kun indlæses, når hold- og venue-ID'er kan valideres.
- Gamle sæsoner må ikke blandes ind i aktuelt dansk kampprogram.
- En CSV-revision skal kunne spores fra rækkevis kontrol til app-release.

## Næste modelbeslutninger

Story 3.6 og Story 10.2 skal fastlægge:

- den autoritative klub-, stadion-, række- og sæsonmodel i CSV
- ID- og historikregler
- versionering af reference-datasæt og app-releases
- kontrolfil og validering før release
- rollback til seneste app-version ved fejl
