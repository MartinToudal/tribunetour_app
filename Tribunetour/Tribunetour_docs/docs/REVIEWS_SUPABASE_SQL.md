# Reviews Supabase SQL

Brug denne SQL til at oprette første shared backend for `reviews`.

Kør blokkene i rækkefølge i Supabase SQL Editor.

## Trin 1: Opret tabel

```sql
create table if not exists public.reviews (
  user_id uuid not null references auth.users(id) on delete cascade,
  club_id text not null,
  match_label text not null default '',
  scores jsonb not null default '{}'::jsonb,
  category_notes jsonb not null default '{}'::jsonb,
  summary text not null default '',
  tags text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  source text not null default 'web'
);
```

## Trin 2: Unik constraint

```sql
alter table public.reviews
  drop constraint if exists reviews_user_id_club_id_key;

alter table public.reviews
  add constraint reviews_user_id_club_id_key unique (user_id, club_id);
```

## Trin 3: Indeks

```sql
create index if not exists reviews_user_id_idx on public.reviews(user_id);
create index if not exists reviews_club_id_idx on public.reviews(club_id);
```

## Trin 4: Check constraint for source

```sql
alter table public.reviews
  drop constraint if exists reviews_source_check;

alter table public.reviews
  add constraint reviews_source_check
  check (source in ('ios', 'web', 'shared'));
```

## Trin 5: Auto-opdater updated_at

```sql
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_reviews_updated_at on public.reviews;

create trigger set_reviews_updated_at
before update on public.reviews
for each row
execute function public.set_updated_at();
```

## Trin 6: Grants

```sql
grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on public.reviews to authenticated;
```

## Trin 7: Slå RLS til

```sql
alter table public.reviews enable row level security;
```

## Trin 8: RLS policies

```sql
drop policy if exists "reviews_select_own" on public.reviews;
create policy "reviews_select_own"
on public.reviews
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "reviews_insert_own" on public.reviews;
create policy "reviews_insert_own"
on public.reviews
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "reviews_update_own" on public.reviews;
create policy "reviews_update_own"
on public.reviews
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "reviews_delete_own" on public.reviews;
create policy "reviews_delete_own"
on public.reviews
for delete
to authenticated
using (auth.uid() = user_id);
```

## Trin 9: Verificér setup

```sql
select *
from information_schema.tables
where table_schema = 'public'
  and table_name = 'reviews';
```

```sql
select policyname, cmd, permissive
from pg_policies
where schemaname = 'public'
  and tablename = 'reviews'
order by policyname;
```

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'reviews'
order by ordinal_position;
```
