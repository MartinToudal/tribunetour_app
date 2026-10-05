# Flow Inventory

Senest opdateret: 2026-10-05

Dette er et arbejdsinventar over de faktiske flows i Tribunetour. Det bruges til at planlægge migrationsarbejdet efter den godkendte target-arkitektur.

Statusser:

- **Aktiv:** Skal bevares og understøttes.
- **Overgang:** Virker nu, men skal forenkles, flyttes eller samles.
- **Udfaset:** Må ikke være en del af den fremtidige produktoplevelse.
- **Parkeret:** Findes eller er planlagt, men er ikke en aktuel kerneleverance.

## Appflows

| Flow | Status | Nuværende ejer | Mål |
|---|---|---|---|
| App-start og Danmark-first load | Aktiv | iOS `AppState` | Bevar og gør uafhængig af internationale data |
| Bundlet klub-/stadiondata | Aktiv/overgang | iOS CSV-importer | Bevar som versionsstyret redaktionel kilde |
| On-demand landepakker | Aktiv | iOS `CSVClubImporter` og `LeaguePackCatalog` | Bevar som gratis inspirationsscope |
| Dansk fixture-load fra remote feed | Aktiv | iOS `RemoteFixturesProvider` | Bevar med cache og lokal fallback |
| Lokal fixture-fallback | Aktiv | `fixtures_denmark.csv` | Bevar som sikkerhedsnet |
| Fixture-scope og sæsonfilter | Aktiv | iOS fixture-loader | Bevar og test mod Klub 48 |
| Stadionsvisning og kort | Aktiv | SwiftUI-stadionviews | Bevar og stabilisér |
| Kampevisning | Aktiv | `MatchesView` | Kun danske Klub 48-fixtures |
| Min tur/statistik | Aktiv | iOS stores og views | Danmark som hovedscope, internationalt som tilvalg |
| Login | Aktiv | AppAuth/Supabase Auth | Bevar |
| Visited, noter, fotos og reviews | Aktiv/overgang | iOS sync-spor og Supabase/CloudKit | Saml ejerskab uden at miste brugerdata |
| Weekendplan | Overgang | `WeekendPlanStore`, `CloudPlanSync` og relaterede views er stadig aktive | Fjernes efter sikker migrering og verifikation |
| Premium-/league-pack adgang | Overgang | `LeaguePackCatalog`, `PremiumAccessStatusCard` og adgangsmodeller er stadig aktive | Fjernes eller isoleres uden at påvirke gratis scope |

## Web- og driftsflows

| Flow | Status | Nuværende ejer | Mål |
|---|---|---|---|
| Offentlig web-visning | Udfaset | Web-repositoriet/Vercel | Fjernes som brugerflade |
| Intern Klubtjek | Parkeret | Web + Supabase | Bevares kun hvis det senere viser sig nødvendigt |
| Dagligt dansk fixture-check | Aktiv | GitHub Actions i web-repo | Bevar kun for danske fixtures |
| Fixture audit | Aktiv/overgang | GitHub Actions i web-repo | Forenkles og afgrænses til dansk drift |
| Fixture mailrapporter | Aktiv/overgang | Web scripts/GitHub Actions | Bevar kun hvis de giver konkret driftsværdi |
| Fixture feed-publicering | Aktiv | Web-repo/Vercel | Bevar, indtil fixture-driften er flyttet eller forenklet |
| Reference-data JSON-generering | Overgang | Web scripts | Generér kun nødvendige artefakter fra CSV-kilden |
| Admin-backlog UI | Parkeret | Web-repositoriet | Markdown er sandheden indtil videre |
| Dagligt manuelt klubtjek | Overgang | Planlagt GitHub Action + web | Erstattes af halvårlig rækkevis CSV-gennemgang, hvorefter workflowet kan deaktiveres |
| Vercel hosting | Overgang | Web-repo/Vercel | Reducér til nødvendige driftsfunktioner |

## Dataflows

| Dataflow | Status | Nuværende sandhed | Target |
|---|---|---|---|
| Klub/stadion/række | Overgang | App-bundles og landepakker | Versionerede redaktionelle CSV-filer |
| Danske fixtures | Aktiv/overgang | Web-feed med app-cache/fallback | Samme danske fixture-pipeline med klar ejer |
| Brugerens visited-data | Aktiv/overgang | Flere sync-spor | Ét dokumenteret sync-ejerskab uden tab af historik |
| Klubtjek-rettelser | Parkeret | Supabase reviews/overrides | CSV-rettelse ved halvårlig gennemgang |
| Historiske medlemskaber | Aktiv/overgang | CSV-landepakker | Stabil CSV-model med faste ID- og sæsonregler |
| Backlog | Aktiv | `WORKING_BACKLOG.md` | Markdown fortsætter som source of truth |

## Flows der skal fjernes eller isoleres

Følgende må ikke fortsætte som skjulte parallelle produktflows:

- internationale fixtures i brugerrettet appoplevelse
- offentlig webvisning af produktet
- premium-gates og premium-copy
- Plan som brugerrettet produktfunktion
- direkte redigering af samme reference-data flere steder
- Klubtjek som nødvendig distributionsvej
- lokale midlertidige fixtures, der kan overskrive det danske scope uden validering

## Migration order

1. Verificér dette inventar mod den aktuelle kode og workflows.
2. Dokumentér sync-ejerskab for visited, noter, fotos og reviews.
3. Fjern eller isolér udfasede appflows uden at ændre reference-data endnu.
4. Fastlæg CSV-kontrakt, ID-regler og validering.
5. Byg halvårlig rækkevis datagennemgang.
6. Forenkle web-repositoriet til nødvendige fixture- og driftsflows.
7. Fjern gammel kode og jobs efter en dokumenteret verifikation.

## Accept for flow-inventaret

Inventaret er klar til migrationsarbejde, når hvert flow har:

- en status
- en ejer
- en targetplacering
- en beslutning om bevar, flyt, isolér eller fjern
- en test eller verifikation, der kan vise at migrationen er sikker

## Verifikation mod kode og workflows

Første verifikation er gennemført 2026-10-05. Den dækker de centrale flows, men er ikke en fuld linje-for-linje revision af begge repositories.

- `AppState` indlæser Danmark først via bundlede CSV-data og starter fixture-load i baggrunden.
- `CSVClubImporter` indlæser landepakker on demand.
- `RemoteFixturesProvider` filtrerer, sæsonguarder og deduplikerer remote fixtures med cache og lokal fallback.
- `WeekendPlanStore` og `CloudPlanSync` findes stadig i appens runtime-flow og skal derfor migreres, før Plan kan betragtes som udfaset.
- `LeaguePackCatalog`, premium-adgangsmodeller og relateret admin/backend-kode findes stadig og skal isoleres eller fjernes kontrolleret.
- `daily-fixture-check.yml`, `fixture-audit.yml` og `daily-manual-club-check.yml` findes stadig i web-repositoriets drift.
- Remote har desuden `compare-danish-fixture-sources.yml`, som ikke findes i den lokale divergerede checkout.
- `daily-manual-club-check.yml` har fortsat en planlagt kørsel og er derfor ikke parkeret i praksis endnu.
- Offentlige web-ruter findes stadig; de er en overgangsrisiko, ikke en allerede fjernet brugerflade.

Remote- og Vercel-kontrollen er gennemført 2026-10-05 for den aktuelle production-revision. Den lokale webcheckout er fortsat divergeret og må ikke bruges som deploygrundlag. Se `REPOSITORY_AND_DEPLOY_INVENTORY.md`.
