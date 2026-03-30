# Photos Supabase SQL

Brug denne SQL og bucket-opsætning til første shared backend for `photos`.

Kør SQL-blokkene i rækkefølge i Supabase SQL Editor.

## Trin 1: Opret tabel

```sql
create table if not exists public.photos (
  user_id uuid not null references auth.users(id) on delete cascade,
  club_id text not null,
  file_name text not null,
  caption text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  source text not null default 'web'
);
```

## Trin 2: Unik constraint

```sql
alter table public.photos
  drop constraint if exists photos_user_id_club_id_file_name_key;

alter table public.photos
  add constraint photos_user_id_club_id_file_name_key unique (user_id, club_id, file_name);
```

## Trin 3: Indeks

```sql
create index if not exists photos_user_id_idx on public.photos(user_id);
create index if not exists photos_club_id_idx on public.photos(club_id);
```

## Trin 4: Check constraint for source

```sql
alter table public.photos
  drop constraint if exists photos_source_check;

alter table public.photos
  add constraint photos_source_check
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

drop trigger if exists set_photos_updated_at on public.photos;

create trigger set_photos_updated_at
before update on public.photos
for each row
execute function public.set_updated_at();
```

## Trin 6: Grants

```sql
grant usage on schema public to anon, authenticated, service_role;
grant select, insert, update, delete on public.photos to authenticated;
```

## Trin 7: Slå RLS til

```sql
alter table public.photos enable row level security;
```

## Trin 8: RLS policies

```sql
drop policy if exists "photos_select_own" on public.photos;
create policy "photos_select_own"
on public.photos
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "photos_insert_own" on public.photos;
create policy "photos_insert_own"
on public.photos
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "photos_update_own" on public.photos;
create policy "photos_update_own"
on public.photos
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "photos_delete_own" on public.photos;
create policy "photos_delete_own"
on public.photos
for delete
to authenticated
using (auth.uid() = user_id);
```

## Trin 9: Opret storage bucket

Opret en privat Supabase Storage bucket med navnet:

```text
stadium-photos
```

Bucket skal vaere:
- privat
- kun tilgaengelig for autentificerede brugere via policies

## Trin 10: Storage policies

Juster eventuelt bucket-id, hvis du bruger et andet navn.

```sql
create policy "photos_storage_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'stadium-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "photos_storage_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'stadium-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "photos_storage_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'stadium-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'stadium-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy "photos_storage_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'stadium-photos'
  and auth.uid()::text = (storage.foldername(name))[1]
);
```

## Trin 11: Verificer setup

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'photos'
order by ordinal_position;
```

```sql
select policyname, cmd, permissive
from pg_policies
where schemaname = 'public'
  and tablename = 'photos'
order by policyname;
```

```sql
select id, name, public
from storage.buckets
where id = 'stadium-photos';
```
