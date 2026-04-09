# Germany League Pack

Formål: definere den første konkrete ikke-danske league pack oven på den nye canonical id-model, så vi kan bygge Tyskland som et kontrolleret sidecar-spor uden at gøre Danmark-sættet skrøbeligt.

## Konklusion først

Vi behøver ikke den endelige klubliste endnu for at starte rigtigt.

Det vi kan låse nu er:

- hvilke tyske ligaer der er i scope
- hvilken id-strategi der gælder
- hvilken reference-data-struktur vi vil importere til
- hvordan feature gate og adgang skal se ud
- hvilke UI- og sync-konsekvenser pakken har

Det vi først behøver senere er:

- endelig klub/stadion-liste
- endelige koordinater og stadionnavne
- fixture-kilde og importformat

## Første scope

Den første tyske pakke bør være smal og bevidst.

Anbefalet første scope:

- Bundesliga
- 2. Bundesliga
- 3. Liga

Jeg vil ikke starte med Regionalliga eller lavere endnu.

Grunde:

- datamængden er håndterbar
- de tre lag giver allerede en rigtig “pyramide”
- datakvalitet og stadionmatch er typisk lettere at kontrollere
- produktet bliver hurtigt nyttigt uden at UI bliver rodet

## League pack id

Anbefalet pack-id:

```text
germany_top_3
```

Dermed bliver den overordnede retning:

- `core_denmark`
- `germany_top_3`

Hvis vi senere vil udvide, kan vi gøre det uden at knække første pakke:

- `germany_full_pyramid`
- `england_top_4`

## Liga-metadata

Anbefalede liga-koder i første version:

```text
de-bundesliga
de-2-bundesliga
de-3-liga
```

Anbefalede fælles metadatafelter pr. klub og fixture:

- `countryCode`
- `leagueCode`
- `leaguePack`

Eksempel:

```json
{
  "countryCode": "de",
  "leagueCode": "de-bundesliga",
  "leaguePack": "germany_top_3"
}
```

## Club id-strategi

Tyskland skal bygges direkte på canonical ids, ikke forkortelser.

Anbefalet format:

```text
de-bayern-munchen
de-borussia-dortmund
de-hamburger-sv
de-fc-st-pauli
```

Regler:

- ASCII-only
- landeprefix først
- stabil klubidentitet frem for sæsonspecifik branding
- ingen lokale UI-forkortelser som primær nøgle

Forkortelser lever som separat felt:

```text
FCB
BVB
HSV
S04
```

## Data vi skal have pr. klub

Minimum for første import:

- `id`
- `team`
- `stadiumName`
- `league`
- `city`
- `lat`
- `lon`
- `countryCode`
- `leagueCode`
- `leaguePack`
- `shortCode`

Det betyder i praksis, at Tyskland skal kunne ende i samme reference-kontrakt som Danmark, men med ekstra scope-felter.

## Fixture-strategi

Vi bør ikke ændre fixture-id-format nu, før vi har første tyske import klar.

Anbefalet retning når vi gør det:

- fixture ids må godt være liga-/runde-baserede
- `homeTeamId`, `awayTeamId`, `venueClubId` skal altid pege på canonical club ids
- remote app-feed skal fortsat kunne være bagudkompatibelt, hvis en live appversion ikke endnu forstår et nyt format

## UI-konsekvenser

Når `germany_top_3` er inaktiv:

- tyske klubber vises ikke
- tyske stadions vises ikke
- tyske kampe vises ikke
- progression og achievements tæller dem ikke med

Når `germany_top_3` er aktiv:

- Danmark forbliver default
- brugeren skal kunne filtrere eller gruppere efter land/liga
- weekendplan skal kunne inkludere tyske kampe
- stats/progression skal kunne vises både samlet og pr. scope

## Web-adgang

På web skal Tyskland være login-bundet fra starten.

Det betyder:

- ikke-loggede brugere ser kun Danmark
- loggede brugere får adgang via centralt brugerflag eller entitlement
- server og klient skal begge filtrere efter aktive packs

Det passer godt med den retning vi allerede har lagt i `MULTI_LEAGUE_EXPERIMENT.md`.

## App-adgang

I første version kan vi godt bruge en intern toggle i `Interne Værktøjer`.

Men den bør ses som et testværktøj, ikke som den langsigtede adgangsmodel.

Målet er:

- central adgangskilde
- lokal toggle kun som debug-hjælp

## Hvad vi behøver fra klublisten senere

Når vi går fra design til import, skal vi have:

1. endelig liste over klubber i de tre ligaer
2. stadionnavne vi vil vise i produktet
3. verificerede koordinater
4. beslutning om navneform:
   - lokal tysk form
   - eller en mere international/translittereret visning
5. short codes til UI

## Anbefalet næste rækkefølge

1. Lås Tyskland-scope til `Bundesliga`, `2. Bundesliga`, `3. Liga`
2. Lås `leaguePack = germany_top_3`
3. Lav første klub-id-draft for de tyske klubber
4. Lav første reference-data-draft for klubber/stadions
5. Importér derefter fixtures
6. Først bagefter aktivér pakken i app/web

## Beslutning

Min klare anbefaling er:

- vi starter uden den endelige klubliste
- vi låser først pakke-id, liga-scope og id-regler
- og derefter bygger vi den første tyske klubmapping som næste konkrete trin

Det er den sikreste måde at undgå endnu en dyr oprydning senere.
