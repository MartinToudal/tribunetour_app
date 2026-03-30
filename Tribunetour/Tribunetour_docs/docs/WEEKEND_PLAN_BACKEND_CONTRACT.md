# Weekend Plan Backend Contract

## Formål
Dette dokument definerer backend-kontrakten for shared `weekend plan`, så app og web kan skrive og læse samme plan-snapshot for den aktuelle bruger.

## Tabel
`public.weekend_plans`

En række per bruger:

- `user_id uuid primary key references auth.users(id) on delete cascade`
- `fixture_ids text[] not null default '{}'`
- `updated_at timestamptz not null`
- `source text not null default 'web'`

## Læsekontrakt
Klienter læser ét snapshot for den aktuelle bruger.

Forventet form:

```json
{
  "fixture_ids": ["vff-bif-2026-02-14", "fcm-agf-2026-02-15"],
  "updated_at": "2026-03-30T20:15:00.000Z",
  "source": "ios"
}
```

## Skrivekontrakt
Klienter skriver hele planen som ét nyt snapshot.

Det betyder:
- ingen patch-operation pr. fixture
- nyeste `updated_at` vinder i konflikt
- tom array betyder "brugeren har ingen aktiv plan"

## Merge-regel
`weekend plan` er ikke historik.

Derfor er merge-reglen:
- seneste `updated_at` vinder

Hvis to clients skriver tæt på hinanden, skal den sidst skrevne plan være den gældende plan.

## Source-felt
`source` er diagnostisk og bruges til at forstå retningen i sync:

- `ios`
- `web`

Det må ikke bruges som merge-authority alene.

## Auth og RLS
Alle operationer er brugerbundne:

- brugeren kan kun læse sin egen plan
- brugeren kan kun skrive sin egen plan
- brugeren kan kun slette/rydde sin egen plan

## Bemærkning om fixtures
`fixture_ids` er kun stabile, hvis app og web bruger samme fælles fixture-id fra reference-data-pipelinen.
