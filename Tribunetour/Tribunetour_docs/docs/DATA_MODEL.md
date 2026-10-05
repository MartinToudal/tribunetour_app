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
| Klubber/stadions | Bundlet `stadiums.csv` og landepakker | Godkendte centrale rettelser distribueres ikke automatisk endnu |
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

Det mangler stadig:

```text
central godkendelse
  -> versioneret reference-datasæt
  -> appens remote stamdata
```

## Source-of-truth-regler

Indtil den centrale distribution er færdig, skal vi skelne mellem:

1. **Godkendt indhold:** den senest godkendte reference-data, som vi forretningsmæssigt ønsker.
2. **Central lagring:** Supabase-data for Klubtjek og godkendte overrides.
3. **Distribueret artefakt:** web-JSON eller remote-feed, som appen kan hente.
4. **Lokal fallback:** appens bundlet CSV eller cached remote-data.

Lokal fallback er sikkerhedsnet, ikke et alternativt redigeringssted.

## Kritiske integritetsregler

- En klub-ID må ikke skifte ved en koordinat- eller rækkekorrektion.
- En aktiv række skal have land, niveau og sæson, hvor modellen understøtter det.
- Historisk rækketilhør må ikke overskrive aktiv række.
- Fixtures må kun indlæses, når hold- og venue-ID'er kan valideres.
- Gamle sæsoner må ikke blandes ind i aktuelt dansk kampprogram.
- En godkendt central rettelse skal kunne spores fra ændringsforslag til appvisning.

## Næste modelbeslutninger

Story 4.3 skal fastlægge:

- den autoritative klub-, stadion-, række- og sæsonmodel
- prioritet mellem central data, landepakker og fallback
- versionering af reference-datasæt
- distribution til iOS uden ny TestFlight-release for almindelige stamdatarettelser
- rollback ved fejl
