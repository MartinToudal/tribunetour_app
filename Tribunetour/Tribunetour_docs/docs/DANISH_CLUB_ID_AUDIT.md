# Danish Club ID Audit

## Formål
Dette dokument vurderer de nuværende danske klub-/stadion-id'er i `stadiums.csv` set i lyset af planerne om multi-league support.

Målet er:
- at finde nuværende risici
- at pege på hvilke id'er der bør migreres
- at forberede et sikkert fundament før Tyskland tilføjes

Se også:
- `CLUB_ID_POLICY.md`
- `MULTI_LEAGUE_EXPERIMENT.md`

## Snapshot
Datasættet indeholder i dag:
- 48 danske klub-/stadion-records
- ingen nuværende case-insensitive dubletter
- flere korte, kontekstafhængige ids
- 3 non-ASCII ids

### Fund
Non-ASCII ids i nuværende datasæt:
- `brø`
- `hør`
- `næs`

Det er ikke en akut dansk-only blocker, men det er en klar migrationskandidat før multi-league.

## Vurdering af nuværende model
Den nuværende model er:
- kompakt
- menneskelig
- praktisk til et lille dansk scope

Men den er ikke stærk nok som langsigtet canonical model, fordi:
- ids er meget korte
- de mangler landekontekst
- flere ids er forkortelser, ikke identiteter
- non-ASCII gør dem mindre robuste i routes og dataflows

## Anbefalet beslutning
Den anbefalede retning er:
- migrér Danmark til nye canonical ids
- behold nuværende korte ids som alias eller `shortCode` i en overgang
- byg Tyskland direkte på den nye canonical model

## Konkrete migrationskandidater

### Høj prioritet
Disse bør migreres først, fordi de enten er non-ASCII eller for korte/tvetydige:

| Nuværende id | Klub | Foreslået canonical id |
| --- | --- | --- |
| `brø` | Brønshøj | `dk-bronshoj` |
| `hør` | Hørsholm-Usserød IK | `dk-horsholm-usserod-ik` |
| `næs` | Næsby BK | `dk-naesby-bk` |
| `ab` | AB | `dk-akademisk-boldklub` |
| `ob` | OB | `dk-odense-boldklub` |
| `vb` | Vejle Boldklub | `dk-vejle-boldklub` |

### Medium prioritet
Disse er ikke farlige i sig selv, men er stadig meget shorthand-prægede:

| Nuværende id | Klub | Foreslået canonical id |
| --- | --- | --- |
| `agf` | AGF | `dk-agf` |
| `fck` | F.C. København | `dk-fc-copenhagen` |
| `fcm` | FC Midtjylland | `dk-fc-midtjylland` |
| `fcn` | FC Nordsjælland | `dk-fc-nordsjaelland` |
| `bif` | Brøndby IF | `dk-brondby-if` |
| `sif` | Silkeborg IF | `dk-silkeborg-if` |
| `vff` | Viborg FF | `dk-viborg-ff` |
| `efb` | Esbjerg fB | `dk-esbjerg-fb` |
| `hik` | HIK | `dk-hik` |
| `hbk` | HB Køge | `dk-hb-koge` |

### Lavere prioritet
Nogle ids er allerede rimeligt sigende, men bør stadig have landekode for at være globale:

| Nuværende id | Klub | Foreslået canonical id |
| --- | --- | --- |
| `ran` | Randers FC | `dk-randers-fc` |
| `ros` | FC Roskilde | `dk-fc-roskilde` |
| `kol` | Kolding IF | `dk-kolding-if` |
| `mid` | Middelfart | `dk-middelfart` |
| `hol` | Holbæk B&I | `dk-holbaek-bi` |

## Hvad der ikke er nok
Det er ikke nok at “være lidt mere konsekvent med forkortelser”.

Hvis Tyskland kommer ind, opstår der hurtigt spørgsmål som:
- hvad betyder `fcb`?
- hvad betyder `svw`?
- hvad gør vi hvis to klubber deler populær forkortelse?
- hvad gør vi når en forkortelse er logisk i ét land, men uklar globalt?

Derfor bør:
- forkortelser blive UI-felter
- canonical ids blive stabile, landebundne slug-ids

## Migrationsstrategi
Den sikreste rækkefølge er:
1. Tilføj policy for canonical ids
2. Fastlæg mapping for alle danske ids
3. Opdatér `stadiums.csv`
4. Opdatér `fixtures.csv`
5. Opdatér web-artefakter
6. Planlæg bevidst migration af brugerdata på gamle ids
7. Først derefter læg tyske klubber ind

## Tysk næste step
Hvis Tyskland er næste geografiske pack, bør næste rigtige tekniske step være:
- definér canonical ids for Bundesliga-klubber og stadions fra start
- importér ikke tyske klubber med korte forkortelses-ids som primær nøgle
- hold `shortCode` som separat felt

Eksempler:
- `de-borussia-dortmund` + `BVB`
- `de-bayern-munich` + `FCB`
- `de-schalke-04` + `S04`
- `de-st-pauli` + `FCSP`

## Konklusion
Danmark-datasættet er godt nok til den nuværende version, men ikke stærkt nok som langsigtet multi-league foundation.

Det rigtige næste skridt før Tyskland er:
- lås canonical id-policy
- migrér danske ids bevidst
- byg derefter den tyske pack på den nye model
