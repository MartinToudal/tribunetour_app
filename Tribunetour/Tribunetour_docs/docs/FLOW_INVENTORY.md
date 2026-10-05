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
| Weekendplan | Udfaset produktflow | `WeekendPlanStore` og relaterede views | Fjernes efter sikker migrering og verifikation |
| Premium-/league-pack adgang | Udfaset produktflow | `PremiumAccessStatusCard` og adgangsmodeller | Fjernes eller isoleres uden at påvirke gratis scope |

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
| Dagligt manuelt klubtjek | Parkeret | GitHub Actions + web | Erstattes af halvårlig rækkevis CSV-gennemgang |
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
