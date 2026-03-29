# Notes Supabase SQL

## Formål
Dette dokument er den konkrete SQL-plan for at oprette første shared `notes`-model i Supabase.

Det er skrevet til at kunne køres i Supabase SQL Editor.

Målet er at:
- oprette `notes`-tabellen
- beskytte den med RLS
- gøre webens første notes-flow skrivbart
- holde modellen smal og kompatibel med den besluttede notes-kontrakt

## Forudsætninger
Denne plan antager:
- Supabase Auth er i brug
- bruger-id kommer fra `auth.users.id`
- `visited` allerede kører i samme projekt
- notes kun gælder personlige stadionnoter i første version

## Målmodel
Tabellen skal rumme:
- `user_id`
- `club_id`
- `note`
- `source`
- `created_at`
- `updated_at`

Der skal kun findes én række pr.:
- `user_id`
- `club_id`

## Trin 1: Opret tabel

```sql
create table if not exists public.notes (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    club_id text not null,
    note text not null default '',
    source text not null default 'web',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);
```

## Trin 2: Unik constraint

```sql
alter table public.notes
    add constraint notes_user_id_club_id_key unique (user_id, club_id);
```

Hvis constrainten allerede findes, skal du ikke køre den igen.

## Trin 3: Indeks

```sql
create index if not exists notes_user_id_idx on public.notes (user_id);
create index if not exists notes_club_id_idx on public.notes (club_id);
create index if not exists notes_user_id_updated_at_idx on public.notes (user_id, updated_at desc);
```

## Trin 4: Check constraint for `source`

```sql
alter table public.notes
    add constraint notes_source_check
    check (source in ('web', 'ios', 'migration'));
```

## Trin 5: Auto-opdater `updated_at`
Hvis funktionen allerede findes fra `visited`, kan du genbruge den.

```sql
create or replace function public.set_current_timestamp_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;
```

```sql
drop trigger if exists set_notes_updated_at on public.notes;

create trigger set_notes_updated_at
before update on public.notes
for each row
execute function public.set_current_timestamp_updated_at();
```

## Trin 6: Grants
Det her gør tabellen tilgængelig for den autentificerede webklient.

```sql
grant select, insert, update, delete on public.notes to authenticated;
grant all on public.notes to service_role;
```

## Trin 7: Slå RLS til

```sql
alter table public.notes enable row level security;
```

## Trin 8: RLS policies
Brugeren må kun læse og skrive sine egne rækker.

### Select

```sql
drop policy if exists "notes_select_own" on public.notes;

create policy "notes_select_own"
on public.notes
for select
using (auth.uid() = user_id);
```

### Insert

```sql
drop policy if exists "notes_insert_own" on public.notes;

create policy "notes_insert_own"
on public.notes
for insert
with check (auth.uid() = user_id);
```

### Update

```sql
drop policy if exists "notes_update_own" on public.notes;

create policy "notes_update_own"
on public.notes
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

### Delete
Delete er ikke nødvendig for første webflow, men kan være praktisk ved senere oprydning.

```sql
drop policy if exists "notes_delete_own" on public.notes;

create policy "notes_delete_own"
on public.notes
for delete
using (auth.uid() = user_id);
```

## Trin 9: Verificér setup

### Findes tabellen?

```sql
select *
from information_schema.tables
where table_schema = 'public'
  and table_name = 'notes';
```

### Ser policies rigtige ud?

```sql
select policyname, cmd, permissive
from pg_policies
where schemaname = 'public'
  and tablename = 'notes'
order by policyname;
```

### Sanity check på rækker

```sql
select user_id, club_id, note, source, updated_at
from public.notes
order by updated_at desc
limit 20;
```

### Find dubletter

```sql
select user_id, club_id, count(*)
from public.notes
group by user_id, club_id
having count(*) > 1;
```

## Trin 10: Hurtig manuel test
Når SQL'en er kørt:
1. log ind på web med en rigtig bruger
2. åbn en stadiondetaljeside
3. skriv en note
4. gem noten
5. refresh siden
6. bekræft at noten stadig vises

## Mest sandsynlige fejl hvis save stadig fejler

### `relation "notes" does not exist`
Tabellen er ikke oprettet endnu.

### `permission denied` eller `new row violates row-level security policy`
RLS/grants/policies er ikke på plads.

### `column ... does not exist`
Kolonnenavnene matcher ikke webens kontrakt.

Weben forventer disse felter:
- `user_id`
- `club_id`
- `note`
- `updated_at`
- `source`
