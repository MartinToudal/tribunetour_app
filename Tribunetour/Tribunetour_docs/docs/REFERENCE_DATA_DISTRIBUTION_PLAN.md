# Reference Data Distribution Plan

Senest opdateret: 2026-10-05

## Formål

Godkendte ændringer fra Klubtjek skal kunne blive synlige i iOS uden en ny TestFlight-release, samtidig med at appen stadig kan starte og fungere med lokal fallback.

Planen gælder reference-data:

- klubber
- stadions
- aktive rækker
- sæsoner og historiske medlemskaber
- danske fixtures som separat datasæt

Brugerdata som visited, noter, fotos og reviews er ikke en del af dette feed.

## Anbefalet ejerskab

### Supabase

Supabase er den centrale, godkendte kilde for stamdata og ændringshistorik.

Supabase skal kunne repræsentere:

- stabil klubidentitet
- stadion og koordinater
- land, niveau og aktiv række
- sæsonrelationer og historik
- datakilde, kontrolstatus og seneste godkendelse

### Publiceret snapshot

Et separat versionsstyret JSON-snapshot distribueres til appen. Snapshot-formatet er optimeret til læsning og skal ikke være direkte redigerbart af appen.

Det kan i første overgang publiceres gennem det eksisterende web-/driftslag. Det er en distributionsmekanisme, ikke en ny brugervendt webflade.

### iOS

iOS læser snapshot'et efter den lokale Danmark-first opstart:

```text
publiceret reference-snapshot
  -> validering
  -> lokal cache
  -> merge med fallback efter fast precedence
  -> AppState / views
```

Hvis snapshot'et ikke kan hentes eller valideres, bruges seneste gyldige cache og derefter appens bundlede data.

## Snapshot-kontrakt

Topniveauet skal indeholde:

```json
{
  "metadata": {
    "version": "2026-10-05T12:00:00Z-abc123",
    "generatedAt": "2026-10-05T12:00:00Z",
    "schemaVersion": 1,
    "checksum": "..."
  },
  "clubs": [],
  "memberships": [],
  "stadiums": []
}
```

Fixtures fortsætter i et separat dansk feed, så stamdata og kampdata kan opdateres uafhængigt.

Minimum for `clubs`/`stadiums`:

- stabil `id`
- klubnavn og visningsnavn
- land
- stadionnavn og by
- koordinater
- aktiv række
- sæson
- eventuel arkivstatus

Minimum for `memberships`:

- stabil `clubId`
- land
- række
- sæson
- status, eksempelvis aktiv, historisk eller arkiveret

## Precedence

Når appen kombinerer data, gælder denne rækkefølge:

1. Seneste validerede centrale snapshot.
2. Seneste validerede snapshot i lokal cache.
3. Bundlede CSV- og landepakkedata.

Et ugyldigt eller ufuldstændigt snapshot må aldrig overskrive et gyldigt datasæt med tomme eller ukendte værdier.

## Publiceringsflow

1. Admin gennemfører Klubtjek.
2. Ændringsforslag gemmes og godkendes centralt.
3. Publiceringsjob validerer klub-ID, række, land, sæson og koordinater.
4. Jobbet genererer snapshot med ny version og checksum.
5. Snapshot publiceres atomisk.
6. iOS henter og validerer snapshot ved næste relevante opstart eller refresh.
7. Appen logger version, kilde og fallbackstatus.
8. Fejl stopper publiceringen og bevarer seneste gyldige snapshot.

## Sikkerheds- og driftsregler

- iOS må kun læse reference-snapshot; rettelser sker i Klubtjek.
- En almindelig koordinat- eller rækkekorrektion kræver ikke ny app-build.
- Ændring af skema kræver versionsforøgelse og kompatibilitetskontrol.
- Hvert snapshot skal kunne rulles tilbage til en tidligere version.
- Snapshot'et må ikke indeholde brugerdata eller hemmelige nøgler.
- Appen skal kunne vise, om den bruger remote, cache eller lokal fallback.

## Første implementeringssnit

Vi starter ikke med at flytte alle lande. Første snit er:

1. Danmark, klubber/stadions og aktiv række.
2. Én godkendt koordinatændring fra Klubtjek.
3. Snapshot-publicering.
4. iOS-loader med cache og lokal fallback.
5. End-to-end-test, hvor ændringen bliver synlig uden TestFlight-release.

Når dette er stabilt, kan historiske medlemskaber og internationale landepakker flyttes over samme kontrakt.

## Åbne beslutninger før kode

- Om snapshot'et skal ligge i Supabase Storage eller fortsat leveres gennem det eksisterende web-/Vercel-lag i overgangsperioden.
- Om Supabase-tabellerne skal udvides til fuld stamdata, eller om et publiceringsjob skal læse fra eksisterende `stadiums` og override-tabeller.
- Om appen skal hente Danmark først og øvrige lande efter valg fra samme snapshot eller fra landespecifikke snapshots.

Disse beslutninger skal afklares, før vi ændrer produktionsschema eller appens loader.
