# Weekend Plan Shared Model

## Formål
Dette dokument definerer den første fælles kontrakt for `weekend plan`, så app og web kan arbejde mod samme model og ikke to parallelle plan-spor.

## Nuværende app-model
Appen bruger i dag en meget lille planmodel:

- `fixtureIds: Set<String>`
- `updatedAt: Date`

Den aktuelle implementation ligger i:
- `WeekendPlanStore.swift`
- `CloudPlanSync.swift`

## Foreslået shared model
Den første shared model bør bevare samme form:

- `user_id: uuid`
- `fixture_ids: text[]`
- `updated_at: timestamptz`
- `source: text`

Praktisk payload-seam:

- `fixtureIds: string[]`
- `updatedAt: ISO-8601 string`
- `source: 'ios' | 'web'`

## Semantik

### Source of truth
`weekend plan` er brugerens aktuelle udvalg af kampe, ikke en historik.

Det betyder:
- hele planen kan opdateres som ét snapshot
- tom plan er en gyldig tilstand
- merge bør være simpel: nyeste `updatedAt` vinder

### Fixture-ID stabilitet
Planen må kun referere til fixtures via stabile fælles fixture-id'er.

Det betyder:
- web og app skal bruge samme fixture-id
- reference-data-pipelinen er en forudsætning for delt plan

## App boundary
Appen skal ikke kobles direkte fra views til shared backend.

Boundary-laget er nu:
- `AppWeekendPlanStore`

Det betyder:
- views taler med `AppWeekendPlanStore`
- nuværende CloudKit-model kan blive bagved boundary’en i overgangsfasen
- shared backend kan kobles på senere uden at ændre `WeekendPlannerView`

## Første integrationsretning
Første version af shared `weekend plan` bør bygges sådan:

1. app-side boundary
2. backend-kontrakt
3. web repository/hook
4. første web-UI
5. app/web sync med `updatedAt` som konfliktregel

## Ikke i første iteration
Disse ting bør ikke være del af første shared version:

- delte planer mellem flere brugere
- flere navngivne planer pr. bruger
- historik eller plan-arkiv
- transport, hotel eller ekstra metadata pr. fixture

Første shared plan skal kun løse:
- "hvilke kampe har brugeren valgt lige nu?"
