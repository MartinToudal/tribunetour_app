# Club ID Policy

## Formål
Dette dokument fastlægger den fremtidige politik for klub- og stadion-id'er i Tribunetour.

Målet er:
- at undgå kollisioner på tværs af lande og ligaer
- at undgå skrøbelige id'er baseret på lokale forkortelser
- at gøre reference-data sikre at udvide med flere league packs
- at beskytte brugerdata, routes, fixtures og sync mod senere id-kaos

## Problemet vi vil undgå
Den nuværende danske model bruger korte ids som:
- `agf`
- `fck`
- `ran`

Det fungerer i en lille, dansk-only verden, men bliver hurtigt skrøbeligt når:
- flere lande kommer til
- flere klubber bruger samme eller lignende forkortelser
- der opstår behov for premium packs eller bruger-specifik adgang

Derudover findes der allerede non-ASCII ids i datasættet, fx:
- `brø`
- `hør`
- `næs`

Det er en unødig risiko, fordi ids også bruges i:
- appens og webens routes
- visited/notes/reviews/photos/weekend plan
- fixtures relationer
- backend-tabeller
- JSON- og feed-distribution

## Grundregel
En klub/stadion-identitet skal have:
- ét globalt unikt canonical id
- ét valgfrit menneskevenligt shortcode-felt

Shortcode er ikke det samme som canonical id.

## Canonical id
Canonical id er den primære nøgle i hele systemet.

Canonical id skal være:
- globalt unikt
- ASCII-only
- lowercase
- stabilt over tid
- uafhængigt af sponsor- og navneændringer
- læsbart nok til debugging, men ikke afhængigt af “smarte” forkortelser

### Anbefalet format
Foreslået format:

```text
{countryCode}-{clubSlug}
```

Eksempler:
- `dk-agf`
- `dk-fc-copenhagen`
- `dk-bronshoj`
- `de-borussia-dortmund`
- `de-bayern-munich`
- `de-hamburger-sv`

Dette giver:
- global navnerumskontrol via landekode
- menneskeligt læsbare ids
- mindre risiko for tilfældige kollisioner

## Shortcode
Shortcode er et separat felt, som gerne må være kort og UI-venligt.

Eksempler:
- `AGF`
- `FCK`
- `BVB`
- `HSV`

Shortcode må gerne bruges til:
- visning
- badges
- små filtre
- intern genkendelse

Shortcode må ikke bruges som:
- database-primærnøgle
- route-identitet
- shared user data key
- fixture binding

## Metadata der skal være første-klasses
Hver klub/stadion-record bør fremover kunne bære mindst:
- `id` = canonical id
- `shortCode`
- `countryCode`
- `leagueCode`
- `leaguePack`

Det gør det muligt at:
- filtrere uden særlogik
- adskille produktadgang fra identitet
- udvide reference-data uden nye id-regler pr. land

## Stabilitetsregler
Canonical id må ikke ændres, når:
- stadionnavn ændres
- sponsor ændres
- klubnavn justeres let
- ligaen ændres
- koordinater forbedres

Canonical id må kun ændres ved bevidst migration.

## Forbudte id-mønstre
Følgende bør ikke bruges fremover:
- non-ASCII ids
- ids der kun er 2-3 bogstaver uden navnerum
- ids der er afhængige af aktuel liga
- ids der er afledt af midlertidige sponsor- eller stadionnavne
- ids der kun giver mening i ét land

## Migrationsretning
For nuværende danske data er den anbefalede retning:
- nuværende `id` skal ikke være den endelige model
- vi bør migrere til canonical ids før multi-league import
- nuværende korte ids kan bevares som aliaser eller shortcodes i en overgang

### Anbefalet trinvis migration
1. Definér ny canonical id-policy
2. Auditér nuværende danske ids
3. Fastlæg mapping fra gamle ids til nye canonical ids
4. Opdatér reference-data og fixtures til de nye ids
5. Lav bevidst migration af brugerdata
6. Først derefter importér Tyskland eller andre lande

## Beslutning for Tyskland
Den tyske pack bør ikke bygges på nuværende korte id-model.

Første tyske data skal oprettes direkte med canonical ids efter denne policy.

Det betyder:
- vi importerer ikke `bvb`, `fcb`, `hsv` som primære ids
- vi importerer fx:
  - `de-borussia-dortmund`
  - `de-bayern-munich`
  - `de-hamburger-sv`

Og lader:
- `BVB`
- `FCB`
- `HSV`
leve som `shortCode`

## Konklusion
Hvis Tribunetour skal vokse til flere lande, er det ikke nok at “være forsigtig med forkortelser”.

Vi skal have:
- én klar canonical id-policy
- ét separat shortcode-felt
- en bevidst migration før næste league pack

Det er den billigste måde at undgå fremtidig oprydning i:
- app
- web
- fixtures
- sync
- brugerdata
