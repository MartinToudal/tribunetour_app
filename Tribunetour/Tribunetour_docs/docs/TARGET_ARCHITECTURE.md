# Target Architecture

Senest opdateret: 2026-10-05

## Formål

Dette dokument omsætter de gennemførte PO-interviews til en konkret målarkitektur. Det beskriver, hvad Tribunetour skal være teknisk, før vi bygger nye større funktioner eller laver en større oprydning.

Det er ikke en beslutning om at omskrive alt på én gang. Det er en beslutning om, hvilket slutbillede alle efterfølgende ændringer skal bevæge sig imod.

## Produktets faste grænser

### Brugervendt produkt

- iOS-appen er den eneste brugervendte produktflade.
- Danmark og Klub 48 er kerneoplevelsen.
- Danske fixtures gælder Klub 48.
- Øvrige danske niveauer er primært klub- og stadionkatalog.
- Internationale lande og UEFA-scope er inspiration og sportsturisme.
- Login og sync bevares.
- Premium og offentlig webvisning udfases.

### Internt driftslag

- Web må kun eksistere som internt admin- og driftslag.
- Backend-jobs, fixture-feed og nødvendige scripts kan bevares, men skal have tydeligt ejerskab.
- Klubtjek er et valgfrit historisk/adminspor, ikke en forudsætning for reference-dataflowet.
- Den primære reference-dataarbejdsgang er redaktionel og versionsstyret.

## Target-systemlandskab

```text
iOS app
  |-- bundlede, versionsstyrede reference-datafiler
  |-- dansk fixture-feed med cache/fallback
  |-- login og brugerdata-sync
  |
  +--> Supabase Auth og brugerdata

Redaktionelt dataflow
  |-- CSV-kilder og landepakker
  |-- validering og rækkevis gennemgang
  |-- app-release

Internt driftslag
  |-- danske fixture-jobs og rapporter
  |-- eventuel historik fra Klubtjek
  |-- backlog og systemdokumentation
```

## Dataejerskab

| Dataområde | Target-ejer | Distribution |
|---|---|---|
| Klubber, stadions og rækker | Versionsstyrede CSV-filer i det redaktionelle dataflow | Bundles i iOS-appens release |
| Sæsonhistorik | Versionsstyrede historikfiler | Bundles i iOS-appens release |
| Danske fixtures | Fixture-pipeline med godkendt feed | Remote feed, cache og lokal fallback |
| Visited, noter, fotos og reviews | Supabase/sync-laget | Brugerdata-sync |
| Login | Supabase Auth | Appens auth-klient |
| Kontroller og auditspor | Dokumenteret driftslag, eventuelt Supabase | Ikke nødvendig runtime-afhængighed for appen |
| Backlog | Versionsstyret Markdown nu, eventuelt admin-UI senere | Dokumentation og drift |

## Regler for én sandhed

- Reference-data må ikke redigeres parallelt i app-CSV, web-JSON og Supabase.
- CSV-filerne er redaktionel input; web-JSON og app-bundles er genererede/distribuerede artefakter.
- Fixture-feedet må ikke blive en skjult source of truth for klub- eller stadiondata.
- Supabase må ikke indeholde en alternativ aktiv række, som appen bruger uden at den er med i den redaktionelle release.
- Stabilt klub-ID er bindende på tværs af reference-data og brugerdata.
- En rettelse skal kunne spores fra kilde og kontrol til commit, build og release.

## Repository-struktur

### App-repositoriet

Ejer:

- iOS-kode
- appens reference-CSV og landepakker
- tests
- app-dokumentation

### Web-/driftsrepositoriet

Ejer kun det, der fortsat er nødvendigt:

- danske fixture-jobs og feed-publicering
- audits og rapporter
- interne adminværktøjer, hvis de fortsat bruges
- generering af afledte web-/feed-artefakter

Offentlig webvisning og brugerrettet web-UI skal udfases separat.

### Supabase

Ejer:

- auth
- brugerdata og sync-relaterede tabeller
- eventuel historik fra tidligere Klubtjek

Supabase ejer ikke nødvendigvis klubbens aktuelle række eller koordinater i target-arkitekturen.

## Runtime-principper i iOS

- Appen starter med Danmark og Klub 48.
- Stadions og klubber læses lokalt fra appens bundle.
- Internationale scopes indlæses efter brugerens valg.
- Fixtures indlæses separat og asynkront.
- En fejl i remote fixtures må ikke blokere stadionoplevelsen.
- Reference-dataændringer kræver ny app-release, medmindre vi senere beslutter en særskilt central distribution.
- Brugerdata må ikke gå tabt, når reference-data opdateres.

## Rebuild/rethink-strategi

Vi skal ikke lave et big-bang rebuild. Vi skal bruge en kontrolleret migrering:

1. Frys målarkitekturen og datakontrakterne.
2. Kortlæg gammel kode og markér hvad der er aktivt, overgang eller udfaset.
3. Fjern eller isolér gamle parallelle flows uden at ændre brugeroplevelsen unødigt.
4. Flyt én datakæde ad gangen til target-modellen.
5. Bevar en fungerende app efter hvert trin.
6. Test på en konkret dansk række og Klub 48 før bredere ændringer.
7. Ryd først gammel kode, når den nye kæde er verificeret i drift.

## Faser før ny featureudvikling

### Fase A – Arkitekturafklaring

- Godkend target-systemlandskab.
- Godkend dataejerskab og ID-regler.
- Godkend repositorygrænser.
- Lav komplet inventar over aktive og udfasede flows.

### Fase B – Stabilisering

- Fjern unødvendige premium-, Plan- og offentlige webspor.
- Sikr at appens Danmark-first opstart er uafhængig af internationale data.
- Afgræns fixtures til Klub 48.
- Dokumentér release-, rollback- og fixture-drift.

### Fase C – Redaktionelt dataflow

- Byg CSV-kontrolfil og validering.
- Gennemfør én prøve på en dansk række.
- Generér bundles og feed-artefakter fra samme input.
- Udgiv via en samlet app-release.

### Fase D – Kontrolleret udvidelse

- Stadionprofiler.
- UEFA-scope.
- Europæiske lande.
- Lavere danske niveauer.

## Accept for arkitekturfase

Arkitekturfase A er færdig, når vi har:

- et godkendt target-systemlandskab
- dokumenteret dataejerskab
- dokumenterede repositorygrænser
- en liste over parallelle og udfasede flows
- en migrationsplan med verificerbare delmål

Før dette er opfyldt, starter vi ikke en større ny feature eller en konkret central distributionsløsning.
