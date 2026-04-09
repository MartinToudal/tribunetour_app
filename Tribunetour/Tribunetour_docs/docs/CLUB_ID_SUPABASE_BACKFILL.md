# Club ID Supabase Backfill

Formål: migrere eksisterende shared brugerdata i Supabase fra legacy `club_id`-værdier til canonical `club_id`-værdier, så databasen matcher de nye reference-data og de nye write-paths i app og web.

## Scope

Denne backfill gælder:

- `public.visited`
- `public.notes`
- `public.reviews`
- `public.photos`

Denne backfill gælder ikke endnu:

- `public.weekend_plans`

Grunden er, at `fixture.id` bevidst ikke blev migreret i første reference-data-runde. `weekend_plans.fixture_ids` kan derfor blive på nuværende format indtil videre.

## Før du starter

1. Tag backup eller eksport af de berørte tabeller.
2. Kør backfill i denne rækkefølge:
   - `visited`
   - `notes`
   - `reviews`
   - `photos` metadata
   - evt. foto-storage-paths bagefter
3. Kør valideringsqueries efter hvert trin.

## Club ID map

Brug denne mapping som fælles CTE i queries:

```sql
with club_id_map(legacy_id, canonical_id) as (
  values
    ('aab', 'dk-aab'),
    ('aaf', 'dk-aarhus-fremad'),
    ('ab', 'dk-ab'),
    ('ach', 'dk-ac-horsens'),
    ('agf', 'dk-agf'),
    ('b93', 'dk-b-93'),
    ('bif', 'dk-brondby-if'),
    ('bra', 'dk-brabrand-if'),
    ('brø', 'dk-bronshoj'),
    ('efb', 'dk-esbjerg-fb'),
    ('fa2', 'dk-fa-2000'),
    ('faa', 'dk-fremad-amager'),
    ('fcf', 'dk-fc-fredericia'),
    ('fck', 'dk-fc-kobenhavn'),
    ('fcm', 'dk-fc-midtjylland'),
    ('fcn', 'dk-fc-nordsjaelland'),
    ('fre', 'dk-frem'),
    ('hbk', 'dk-hb-koge'),
    ('hel', 'dk-fc-helsingor'),
    ('hik', 'dk-hik'),
    ('hil', 'dk-hillerod-fodbold'),
    ('hob', 'dk-hobro-ik'),
    ('hol', 'dk-holbaek-bi'),
    ('hør', 'dk-horsholm-usserod-ik'),
    ('hvi', 'dk-hvidovre-if'),
    ('ish', 'dk-ishoj-if'),
    ('kol', 'dk-kolding-if'),
    ('lyn', 'dk-lyngby-boldklub'),
    ('lys', 'dk-if-lyseng'),
    ('mid', 'dk-middelfart'),
    ('næs', 'dk-naesby-bk'),
    ('nas', 'dk-naestved'),
    ('nyk', 'dk-nykobing-fc'),
    ('ob', 'dk-ob'),
    ('odd', 'dk-odder-fodbold'),
    ('ran', 'dk-randers-fc'),
    ('ros', 'dk-fc-roskilde'),
    ('sif', 'dk-silkeborg-if'),
    ('sje', 'dk-sonderjyske'),
    ('ski', 'dk-skive'),
    ('sun', 'dk-sundby-bk'),
    ('thi', 'dk-thisted-fc'),
    ('van', 'dk-vanlose'),
    ('vb', 'dk-vejle-boldklub'),
    ('vej', 'dk-vejgaard-b'),
    ('ven', 'dk-vendsyssel-ff'),
    ('vff', 'dk-viborg-ff'),
    ('vsk', 'dk-vsk-aarhus')
)
```

## Backup-checks

```sql
select club_id, count(*)
from public.visited
group by club_id
order by count(*) desc, club_id;
```

```sql
select club_id, count(*)
from public.notes
group by club_id
order by count(*) desc, club_id;
```

```sql
select club_id, count(*)
from public.reviews
group by club_id
order by count(*) desc, club_id;
```

```sql
select club_id, count(*)
from public.photos
group by club_id
order by count(*) desc, club_id;
```

## 1. Visited

Strategi:

- indsæt canonical rækker ud fra legacy rækker
- hvis både legacy og canonical findes, behold seneste `updated_at`
- slet legacy rækker bagefter

```sql
with club_id_map(legacy_id, canonical_id) as (
  values
    ('aab', 'dk-aab'),
    ('aaf', 'dk-aarhus-fremad'),
    ('ab', 'dk-ab'),
    ('ach', 'dk-ac-horsens'),
    ('agf', 'dk-agf'),
    ('b93', 'dk-b-93'),
    ('bif', 'dk-brondby-if'),
    ('bra', 'dk-brabrand-if'),
    ('brø', 'dk-bronshoj'),
    ('efb', 'dk-esbjerg-fb'),
    ('fa2', 'dk-fa-2000'),
    ('faa', 'dk-fremad-amager'),
    ('fcf', 'dk-fc-fredericia'),
    ('fck', 'dk-fc-kobenhavn'),
    ('fcm', 'dk-fc-midtjylland'),
    ('fcn', 'dk-fc-nordsjaelland'),
    ('fre', 'dk-frem'),
    ('hbk', 'dk-hb-koge'),
    ('hel', 'dk-fc-helsingor'),
    ('hik', 'dk-hik'),
    ('hil', 'dk-hillerod-fodbold'),
    ('hob', 'dk-hobro-ik'),
    ('hol', 'dk-holbaek-bi'),
    ('hør', 'dk-horsholm-usserod-ik'),
    ('hvi', 'dk-hvidovre-if'),
    ('ish', 'dk-ishoj-if'),
    ('kol', 'dk-kolding-if'),
    ('lyn', 'dk-lyngby-boldklub'),
    ('lys', 'dk-if-lyseng'),
    ('mid', 'dk-middelfart'),
    ('næs', 'dk-naesby-bk'),
    ('nas', 'dk-naestved'),
    ('nyk', 'dk-nykobing-fc'),
    ('ob', 'dk-ob'),
    ('odd', 'dk-odder-fodbold'),
    ('ran', 'dk-randers-fc'),
    ('ros', 'dk-fc-roskilde'),
    ('sif', 'dk-silkeborg-if'),
    ('sje', 'dk-sonderjyske'),
    ('ski', 'dk-skive'),
    ('sun', 'dk-sundby-bk'),
    ('thi', 'dk-thisted-fc'),
    ('van', 'dk-vanlose'),
    ('vb', 'dk-vejle-boldklub'),
    ('vej', 'dk-vejgaard-b'),
    ('ven', 'dk-vendsyssel-ff'),
    ('vff', 'dk-viborg-ff'),
    ('vsk', 'dk-vsk-aarhus')
),
legacy_rows as (
  select
    v.user_id,
    m.canonical_id as club_id,
    v.visited_at,
    v.updated_at,
    v.source
  from public.visited v
  join club_id_map m on m.legacy_id = v.club_id
),
upserted as (
  insert into public.visited (user_id, club_id, visited_at, updated_at, source)
  select user_id, club_id, visited_at, updated_at, source
  from legacy_rows
  on conflict (user_id, club_id) do update
  set
    visited_at = case
      when excluded.updated_at >= public.visited.updated_at then excluded.visited_at
      else public.visited.visited_at
    end,
    updated_at = greatest(public.visited.updated_at, excluded.updated_at),
    source = case
      when excluded.updated_at >= public.visited.updated_at then excluded.source
      else public.visited.source
    end
  returning 1
)
delete from public.visited v
using club_id_map m
where v.club_id = m.legacy_id;
```

## 2. Notes

Strategi:

- indsæt canonical rækker ud fra legacy rækker
- hvis både legacy og canonical findes, behold seneste `updated_at`
- slet legacy rækker bagefter

```sql
with club_id_map(legacy_id, canonical_id) as (
  values
    ('aab', 'dk-aab'),
    ('aaf', 'dk-aarhus-fremad'),
    ('ab', 'dk-ab'),
    ('ach', 'dk-ac-horsens'),
    ('agf', 'dk-agf'),
    ('b93', 'dk-b-93'),
    ('bif', 'dk-brondby-if'),
    ('bra', 'dk-brabrand-if'),
    ('brø', 'dk-bronshoj'),
    ('efb', 'dk-esbjerg-fb'),
    ('fa2', 'dk-fa-2000'),
    ('faa', 'dk-fremad-amager'),
    ('fcf', 'dk-fc-fredericia'),
    ('fck', 'dk-fc-kobenhavn'),
    ('fcm', 'dk-fc-midtjylland'),
    ('fcn', 'dk-fc-nordsjaelland'),
    ('fre', 'dk-frem'),
    ('hbk', 'dk-hb-koge'),
    ('hel', 'dk-fc-helsingor'),
    ('hik', 'dk-hik'),
    ('hil', 'dk-hillerod-fodbold'),
    ('hob', 'dk-hobro-ik'),
    ('hol', 'dk-holbaek-bi'),
    ('hør', 'dk-horsholm-usserod-ik'),
    ('hvi', 'dk-hvidovre-if'),
    ('ish', 'dk-ishoj-if'),
    ('kol', 'dk-kolding-if'),
    ('lyn', 'dk-lyngby-boldklub'),
    ('lys', 'dk-if-lyseng'),
    ('mid', 'dk-middelfart'),
    ('næs', 'dk-naesby-bk'),
    ('nas', 'dk-naestved'),
    ('nyk', 'dk-nykobing-fc'),
    ('ob', 'dk-ob'),
    ('odd', 'dk-odder-fodbold'),
    ('ran', 'dk-randers-fc'),
    ('ros', 'dk-fc-roskilde'),
    ('sif', 'dk-silkeborg-if'),
    ('sje', 'dk-sonderjyske'),
    ('ski', 'dk-skive'),
    ('sun', 'dk-sundby-bk'),
    ('thi', 'dk-thisted-fc'),
    ('van', 'dk-vanlose'),
    ('vb', 'dk-vejle-boldklub'),
    ('vej', 'dk-vejgaard-b'),
    ('ven', 'dk-vendsyssel-ff'),
    ('vff', 'dk-viborg-ff'),
    ('vsk', 'dk-vsk-aarhus')
),
legacy_rows as (
  select
    n.user_id,
    m.canonical_id as club_id,
    n.note,
    n.updated_at,
    n.source
  from public.notes n
  join club_id_map m on m.legacy_id = n.club_id
),
upserted as (
  insert into public.notes (user_id, club_id, note, updated_at, source)
  select user_id, club_id, note, updated_at, source
  from legacy_rows
  on conflict (user_id, club_id) do update
  set
    note = case
      when excluded.updated_at >= public.notes.updated_at then excluded.note
      else public.notes.note
    end,
    updated_at = greatest(public.notes.updated_at, excluded.updated_at),
    source = case
      when excluded.updated_at >= public.notes.updated_at then excluded.source
      else public.notes.source
    end
  returning 1
)
delete from public.notes n
using club_id_map m
where n.club_id = m.legacy_id;
```

## 3. Reviews

Strategi:

- indsæt canonical rækker ud fra legacy rækker
- hvis både legacy og canonical findes, behold seneste `updated_at`
- slet legacy rækker bagefter

```sql
with club_id_map(legacy_id, canonical_id) as (
  values
    ('aab', 'dk-aab'),
    ('aaf', 'dk-aarhus-fremad'),
    ('ab', 'dk-ab'),
    ('ach', 'dk-ac-horsens'),
    ('agf', 'dk-agf'),
    ('b93', 'dk-b-93'),
    ('bif', 'dk-brondby-if'),
    ('bra', 'dk-brabrand-if'),
    ('brø', 'dk-bronshoj'),
    ('efb', 'dk-esbjerg-fb'),
    ('fa2', 'dk-fa-2000'),
    ('faa', 'dk-fremad-amager'),
    ('fcf', 'dk-fc-fredericia'),
    ('fck', 'dk-fc-kobenhavn'),
    ('fcm', 'dk-fc-midtjylland'),
    ('fcn', 'dk-fc-nordsjaelland'),
    ('fre', 'dk-frem'),
    ('hbk', 'dk-hb-koge'),
    ('hel', 'dk-fc-helsingor'),
    ('hik', 'dk-hik'),
    ('hil', 'dk-hillerod-fodbold'),
    ('hob', 'dk-hobro-ik'),
    ('hol', 'dk-holbaek-bi'),
    ('hør', 'dk-horsholm-usserod-ik'),
    ('hvi', 'dk-hvidovre-if'),
    ('ish', 'dk-ishoj-if'),
    ('kol', 'dk-kolding-if'),
    ('lyn', 'dk-lyngby-boldklub'),
    ('lys', 'dk-if-lyseng'),
    ('mid', 'dk-middelfart'),
    ('næs', 'dk-naesby-bk'),
    ('nas', 'dk-naestved'),
    ('nyk', 'dk-nykobing-fc'),
    ('ob', 'dk-ob'),
    ('odd', 'dk-odder-fodbold'),
    ('ran', 'dk-randers-fc'),
    ('ros', 'dk-fc-roskilde'),
    ('sif', 'dk-silkeborg-if'),
    ('sje', 'dk-sonderjyske'),
    ('ski', 'dk-skive'),
    ('sun', 'dk-sundby-bk'),
    ('thi', 'dk-thisted-fc'),
    ('van', 'dk-vanlose'),
    ('vb', 'dk-vejle-boldklub'),
    ('vej', 'dk-vejgaard-b'),
    ('ven', 'dk-vendsyssel-ff'),
    ('vff', 'dk-viborg-ff'),
    ('vsk', 'dk-vsk-aarhus')
),
legacy_rows as (
  select
    r.user_id,
    m.canonical_id as club_id,
    r.match_label,
    r.scores,
    r.category_notes,
    r.summary,
    r.tags,
    r.updated_at,
    r.source
  from public.reviews r
  join club_id_map m on m.legacy_id = r.club_id
),
upserted as (
  insert into public.reviews (
    user_id,
    club_id,
    match_label,
    scores,
    category_notes,
    summary,
    tags,
    updated_at,
    source
  )
  select
    user_id,
    club_id,
    match_label,
    scores,
    category_notes,
    summary,
    tags,
    updated_at,
    source
  from legacy_rows
  on conflict (user_id, club_id) do update
  set
    match_label = case
      when excluded.updated_at >= public.reviews.updated_at then excluded.match_label
      else public.reviews.match_label
    end,
    scores = case
      when excluded.updated_at >= public.reviews.updated_at then excluded.scores
      else public.reviews.scores
    end,
    category_notes = case
      when excluded.updated_at >= public.reviews.updated_at then excluded.category_notes
      else public.reviews.category_notes
    end,
    summary = case
      when excluded.updated_at >= public.reviews.updated_at then excluded.summary
      else public.reviews.summary
    end,
    tags = case
      when excluded.updated_at >= public.reviews.updated_at then excluded.tags
      else public.reviews.tags
    end,
    updated_at = greatest(public.reviews.updated_at, excluded.updated_at),
    source = case
      when excluded.updated_at >= public.reviews.updated_at then excluded.source
      else public.reviews.source
    end
  returning 1
)
delete from public.reviews r
using club_id_map m
where r.club_id = m.legacy_id;
```

## 4. Photos metadata

Strategi:

- migrér metadata i `public.photos`
- behold nyere caption/source hvis både legacy og canonical findes
- slet legacy metadata-rækker bagefter

```sql
with club_id_map(legacy_id, canonical_id) as (
  values
    ('aab', 'dk-aab'),
    ('aaf', 'dk-aarhus-fremad'),
    ('ab', 'dk-ab'),
    ('ach', 'dk-ac-horsens'),
    ('agf', 'dk-agf'),
    ('b93', 'dk-b-93'),
    ('bif', 'dk-brondby-if'),
    ('bra', 'dk-brabrand-if'),
    ('brø', 'dk-bronshoj'),
    ('efb', 'dk-esbjerg-fb'),
    ('fa2', 'dk-fa-2000'),
    ('faa', 'dk-fremad-amager'),
    ('fcf', 'dk-fc-fredericia'),
    ('fck', 'dk-fc-kobenhavn'),
    ('fcm', 'dk-fc-midtjylland'),
    ('fcn', 'dk-fc-nordsjaelland'),
    ('fre', 'dk-frem'),
    ('hbk', 'dk-hb-koge'),
    ('hel', 'dk-fc-helsingor'),
    ('hik', 'dk-hik'),
    ('hil', 'dk-hillerod-fodbold'),
    ('hob', 'dk-hobro-ik'),
    ('hol', 'dk-holbaek-bi'),
    ('hør', 'dk-horsholm-usserod-ik'),
    ('hvi', 'dk-hvidovre-if'),
    ('ish', 'dk-ishoj-if'),
    ('kol', 'dk-kolding-if'),
    ('lyn', 'dk-lyngby-boldklub'),
    ('lys', 'dk-if-lyseng'),
    ('mid', 'dk-middelfart'),
    ('næs', 'dk-naesby-bk'),
    ('nas', 'dk-naestved'),
    ('nyk', 'dk-nykobing-fc'),
    ('ob', 'dk-ob'),
    ('odd', 'dk-odder-fodbold'),
    ('ran', 'dk-randers-fc'),
    ('ros', 'dk-fc-roskilde'),
    ('sif', 'dk-silkeborg-if'),
    ('sje', 'dk-sonderjyske'),
    ('ski', 'dk-skive'),
    ('sun', 'dk-sundby-bk'),
    ('thi', 'dk-thisted-fc'),
    ('van', 'dk-vanlose'),
    ('vb', 'dk-vejle-boldklub'),
    ('vej', 'dk-vejgaard-b'),
    ('ven', 'dk-vendsyssel-ff'),
    ('vff', 'dk-viborg-ff'),
    ('vsk', 'dk-vsk-aarhus')
),
legacy_rows as (
  select
    p.user_id,
    m.canonical_id as club_id,
    p.file_name,
    p.caption,
    p.created_at,
    p.updated_at,
    p.source
  from public.photos p
  join club_id_map m on m.legacy_id = p.club_id
),
upserted as (
  insert into public.photos (
    user_id,
    club_id,
    file_name,
    caption,
    created_at,
    updated_at,
    source
  )
  select
    user_id,
    club_id,
    file_name,
    caption,
    created_at,
    updated_at,
    source
  from legacy_rows
  on conflict (user_id, club_id, file_name) do update
  set
    caption = case
      when excluded.updated_at >= public.photos.updated_at then excluded.caption
      else public.photos.caption
    end,
    created_at = least(public.photos.created_at, excluded.created_at),
    updated_at = greatest(public.photos.updated_at, excluded.updated_at),
    source = case
      when excluded.updated_at >= public.photos.updated_at then excluded.source
      else public.photos.source
    end
  returning 1
)
delete from public.photos p
using club_id_map m
where p.club_id = m.legacy_id;
```

## Photos storage-paths

Vigtigt: metadata-backfill alene flytter ikke eksisterende billedfiler i storage.

Hvis gamle fotos stadig ligger i paths som:

- `stadium-photos/{user_id}/fck/{file_name}`

mens den nye kode forventer:

- `stadium-photos/{user_id}/dk-fc-kobenhavn/{file_name}`

så skal storage-objekterne også migreres eller kopieres.

Start med at kortlægge legacy objekter:

```sql
select name
from storage.objects
where bucket_id = 'stadium-photos'
  and (
    name like '%/aab/%' or
    name like '%/aaf/%' or
    name like '%/ab/%' or
    name like '%/ach/%' or
    name like '%/agf/%' or
    name like '%/b93/%' or
    name like '%/bif/%' or
    name like '%/bra/%' or
    name like '%/brø/%' or
    name like '%/efb/%' or
    name like '%/fa2/%' or
    name like '%/faa/%' or
    name like '%/fcf/%' or
    name like '%/fck/%' or
    name like '%/fcm/%' or
    name like '%/fcn/%' or
    name like '%/fre/%' or
    name like '%/hbk/%' or
    name like '%/hel/%' or
    name like '%/hik/%' or
    name like '%/hil/%' or
    name like '%/hob/%' or
    name like '%/hol/%' or
    name like '%/hør/%' or
    name like '%/hvi/%' or
    name like '%/ish/%' or
    name like '%/kol/%' or
    name like '%/lyn/%' or
    name like '%/lys/%' or
    name like '%/mid/%' or
    name like '%/næs/%' or
    name like '%/nas/%' or
    name like '%/nyk/%' or
    name like '%/ob/%' or
    name like '%/odd/%' or
    name like '%/ran/%' or
    name like '%/ros/%' or
    name like '%/sif/%' or
    name like '%/sje/%' or
    name like '%/ski/%' or
    name like '%/sun/%' or
    name like '%/thi/%' or
    name like '%/van/%' or
    name like '%/vb/%' or
    name like '%/vej/%' or
    name like '%/ven/%' or
    name like '%/vff/%' or
    name like '%/vsk/%'
  )
order by name;
```

Selve object-migreringen bør køres som et separat, kontrolleret spor, fordi Supabase SQL alene ikke flytter storage-binary sikkert for os. Her vil jeg hellere bruge en lille scriptet storage-migration med kopi + verificering + delete bagefter.

## Validering efter backfill

Tjek for resterende legacy ids:

```sql
select 'visited' as table_name, count(*) as legacy_rows
from public.visited
where club_id !~ '^dk-'
union all
select 'notes' as table_name, count(*) as legacy_rows
from public.notes
where club_id !~ '^dk-'
union all
select 'reviews' as table_name, count(*) as legacy_rows
from public.reviews
where club_id !~ '^dk-'
union all
select 'photos' as table_name, count(*) as legacy_rows
from public.photos
where club_id !~ '^dk-';
```

Tjek for dubletter:

```sql
select user_id, club_id, count(*)
from public.visited
group by user_id, club_id
having count(*) > 1;
```

```sql
select user_id, club_id, count(*)
from public.notes
group by user_id, club_id
having count(*) > 1;
```

```sql
select user_id, club_id, count(*)
from public.reviews
group by user_id, club_id
having count(*) > 1;
```

```sql
select user_id, club_id, file_name, count(*)
from public.photos
group by user_id, club_id, file_name
having count(*) > 1;
```

## Manuel sanity efter kørsel

Når SQL-backfill er færdig, så kør en kort sanity-runde:

1. Åbn app og web med samme bruger.
2. Tjek et gammelt dansk stadion med eksisterende `visited`, note, review og evt. foto.
3. Bekræft at data stadig vises korrekt begge steder.
4. Lav én ny ændring på et gammelt stadion og bekræft, at den nu skrives tilbage med canonical `club_id`.

## Anbefalet beslutning

Jeg vil anbefale, at vi kører metadata-backfill for `visited`, `notes`, `reviews` og `photos` relativt snart, men tager storage-object migration for fotos som et separat trin med egen verificering.
