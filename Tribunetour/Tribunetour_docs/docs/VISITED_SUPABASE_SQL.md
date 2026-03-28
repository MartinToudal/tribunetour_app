# Visited Supabase SQL

## Formål
Dette dokument er den konkrete SQL-plan for at indføre den nye fælles `visited`-model i Supabase.

Det er skrevet til at kunne bruges direkte i Supabase SQL Editor, men bør køres i kontrollerede trin.

Målet er at:
- oprette den nye `visited`-tabel
- beskytte den med RLS
- migrere data fra den gamle `visits`-tabel
- holde weben kørende under overgangen

## Forudsætninger
Denne plan antager:
- Supabase Auth er i brug
- brugernes id kommer fra `auth.users.id`
- nuværende legacy-tabel hedder `visits`
- legacy-felter er mindst:
  - `user_id`
  - `stadium_id`

## Målmodel
Ny tabel skal repræsentere den fælles model:
- `user_id`
- `club_id`
- `visited`
- `visited_date`
- `source`
- `created_at`
- `updated_at`

## Trin 1: Opret tabel
Kør først dette:

```sql
create table if not exists public.visited (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    club_id text not null,
    visited boolean not null default true,
    visited_date timestamptz null,
    source text not null default 'web',
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);
```

## Trin 2: Unik constraint
Der må kun være én række pr. bruger og klub.

```sql
alter table public.visited
    add constraint visited_user_id_club_id_key unique (user_id, club_id);
```

Hvis constrainten allerede findes, skal du ikke køre den igen.

## Trin 3: Indeks
Disse indeks dækker de vigtigste queries.

```sql
create index if not exists visited_user_id_idx on public.visited (user_id);
create index if not exists visited_club_id_idx on public.visited (club_id);
create index if not exists visited_user_id_visited_idx on public.visited (user_id, visited);
```

## Trin 4: Check constraints
Hold `source` stram i første iteration.

```sql
alter table public.visited
    add constraint visited_source_check
    check (source in ('web', 'ios', 'migration'));
```

Hvis du senere vil udvide med fx `admin` eller `import`, kan constrainten ændres.

## Trin 5: Auto-opdater `updated_at`
Opret først trigger-funktion:

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

Opret derefter trigger:

```sql
drop trigger if exists set_visited_updated_at on public.visited;

create trigger set_visited_updated_at
before update on public.visited
for each row
execute function public.set_current_timestamp_updated_at();
```

## Trin 6: Slå RLS til

```sql
alter table public.visited enable row level security;
```

## Trin 7: RLS policies
Brugeren må kun læse og skrive sine egne rækker.

### Select
```sql
drop policy if exists "visited_select_own" on public.visited;

create policy "visited_select_own"
on public.visited
for select
using (auth.uid() = user_id);
```

### Insert
```sql
drop policy if exists "visited_insert_own" on public.visited;

create policy "visited_insert_own"
on public.visited
for insert
with check (auth.uid() = user_id);
```

### Update
```sql
drop policy if exists "visited_update_own" on public.visited;

create policy "visited_update_own"
on public.visited
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

### Delete
Hvis du vil tillade delete i overgangsfasen:

```sql
drop policy if exists "visited_delete_own" on public.visited;

create policy "visited_delete_own"
on public.visited
for delete
using (auth.uid() = user_id);
```

Bemærk:
- weben er på vej væk fra delete-baseret model
- delete-policy kan stadig være praktisk i overgangsfasen

## Trin 8: Migrér data fra legacy `visits`
Når tabellen er oprettet, migrér legacy-data ind i den nye model.

```sql
insert into public.visited (
    user_id,
    club_id,
    visited,
    visited_date,
    source,
    created_at,
    updated_at
)
select
    v.user_id,
    v.stadium_id,
    true,
    null,
    'migration',
    timezone('utc', now()),
    timezone('utc', now())
from public.visits v
on conflict (user_id, club_id)
do update set
    visited = excluded.visited,
    source = case
        when public.visited.source = 'ios' then public.visited.source
        else excluded.source
    end,
    updated_at = timezone('utc', now());
```

### Bemærkning om `visited_date`
Legacy `visits` ser ikke ud til at have en reel besøgsdato.
Derfor sættes `visited_date = null` i migrationen.

Det er korrekt i første iteration.

## Trin 9: Verificér migrationen
Brug disse sanity checks.

### Tæl rækker
```sql
select count(*) from public.visits;
select count(*) from public.visited;
```

### Find dubletter i ny model
```sql
select user_id, club_id, count(*)
from public.visited
group by user_id, club_id
having count(*) > 1;
```

### Tjek at migrated records er plausible
```sql
select *
from public.visited
order by updated_at desc
limit 20;
```

## Trin 10: Overgangsdrift
Når dette er på plads, er web-repoet allerede forberedt til følgende adfærd:
- først prøve tabel `visited`
- kun falde tilbage til `visits`, hvis `visited` ikke findes

Det betyder:
- så snart tabellen `visited` findes, vil weben begynde at bruge den
- fallback er kun sikkerhedsnet under rollout

## Trin 11: Efter migration
Når du har verificeret at `visited` virker i produktion:
1. test login
2. test markér som besøgt
3. test markér som ubesøgt
4. test at data persists efter refresh
5. test at `Stadions`, `Kampe`, `Kort`, `Min tur`, stadium detail og match detail viser samme status

## Trin 11B: Migration state til app-bootstrap
For at appen kan vide om første-login bootstrap stadig mangler, skal der være en lille status pr. bruger.

```sql
create table if not exists public.visited_migration_state (
    user_id uuid primary key references auth.users(id) on delete cascade,
    bootstrap_completed boolean not null default false,
    bootstrap_source text null,
    bootstrapped_at timestamptz null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);
```

```sql
alter table public.visited_migration_state enable row level security;
```

```sql
drop policy if exists "visited_migration_state_select_own" on public.visited_migration_state;

create policy "visited_migration_state_select_own"
on public.visited_migration_state
for select
using (auth.uid() = user_id);
```

```sql
drop policy if exists "visited_migration_state_insert_own" on public.visited_migration_state;

create policy "visited_migration_state_insert_own"
on public.visited_migration_state
for insert
with check (auth.uid() = user_id);
```

```sql
drop policy if exists "visited_migration_state_update_own" on public.visited_migration_state;

create policy "visited_migration_state_update_own"
on public.visited_migration_state
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

## Trin 11C: RPC til migration state
Appen bør læse migration-state via en RPC, så klientkontrakten er stabil og eksplicit.

```sql
create or replace function public.get_visited_migration_state()
returns jsonb
language plpgsql
security invoker
as $$
declare
    current_state public.visited_migration_state;
begin
    select *
    into current_state
    from public.visited_migration_state
    where user_id = auth.uid();

    if current_state is null then
        return jsonb_build_object(
            'bootstrap_required', true,
            'bootstrapped_at', null,
            'bootstrap_source', null
        );
    end if;

    return jsonb_build_object(
        'bootstrap_required', not current_state.bootstrap_completed,
        'bootstrapped_at', current_state.bootstrapped_at,
        'bootstrap_source', current_state.bootstrap_source
    );
end;
$$;
```

## Trin 11D: RPC til bootstrap fra app
App-bootstrap skal være en separat engangsoperation, ikke bare mange almindelige upserts.

```sql
create or replace function public.bootstrap_visited_from_app(
    source text,
    replace_existing boolean,
    items jsonb
)
returns jsonb
language plpgsql
security invoker
as $$
declare
    item jsonb;
    item_count integer := 0;
    current_user uuid := auth.uid();
    existing_state public.visited_migration_state;
begin
    if current_user is null then
        raise exception 'auth required';
    end if;

    if replace_existing is distinct from true then
        raise exception 'replace_existing must be true in v1 bootstrap';
    end if;

    select *
    into existing_state
    from public.visited_migration_state
    where user_id = current_user;

    if existing_state.bootstrap_completed is true then
        raise exception using errcode = '23505', message = 'bootstrap already completed';
    end if;

    delete from public.visited where user_id = current_user;

    for item in select * from jsonb_array_elements(items)
    loop
        insert into public.visited (
            user_id,
            club_id,
            visited,
            visited_date,
            source
        )
        values (
            current_user,
            item->>'club_id',
            coalesce((item->>'visited')::boolean, false),
            case
                when item->>'visited_date' is null or item->>'visited_date' = '' then null
                else (item->>'visited_date')::timestamptz
            end,
            source
        );

        item_count := item_count + 1;
    end loop;

    insert into public.visited_migration_state (
        user_id,
        bootstrap_completed,
        bootstrap_source,
        bootstrapped_at
    )
    values (
        current_user,
        true,
        source,
        timezone('utc', now())
    )
    on conflict (user_id)
    do update set
        bootstrap_completed = true,
        bootstrap_source = excluded.bootstrap_source,
        bootstrapped_at = excluded.bootstrapped_at,
        updated_at = timezone('utc', now());

    return jsonb_build_object(
        'bootstrapped', true,
        'bootstrap_source', source,
        'bootstrapped_at', timezone('utc', now()),
        'item_count', item_count
    );
end;
$$;
```

Bemærkning:
- denne v1-funktion sletter først brugerens eksisterende shared visited-rækker
- derefter indsætter den appens snapshot som den komplette sandhed
- det matcher den valgte migrationsregel: appen er source of truth ved første bootstrap

## Trin 12: Oprydning senere
Når du er sikker på at al drift ligger på `visited`:
- fjern fallback i repository-laget
- stop med at læse fra `visits`
- beslut om `visits` skal:
  - beholdes kortvarigt
  - arkiveres
  - eller slettes

## Anbefalet rollout
Den sikreste rækkefølge er:
1. opret `visited`
2. slå RLS til
3. opret policies
4. migrér data fra `visits`
5. test live med én bruger
6. behold fallback kortvarigt
7. fjern fallback senere

## Hvad du ikke bør gøre

## Klar Til SQL Editor
Kør disse blokke i rækkefølge.

### 1. `visited_migration_state`
```sql
create table if not exists public.visited_migration_state (
    user_id uuid primary key references auth.users(id) on delete cascade,
    bootstrap_completed boolean not null default false,
    bootstrap_source text null,
    bootstrapped_at timestamptz null,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists visited_migration_state_bootstrap_completed_idx
    on public.visited_migration_state (bootstrap_completed);

alter table public.visited_migration_state enable row level security;

drop policy if exists "visited_migration_state_select_own" on public.visited_migration_state;
create policy "visited_migration_state_select_own"
on public.visited_migration_state
for select
using (auth.uid() = user_id);

drop policy if exists "visited_migration_state_insert_own" on public.visited_migration_state;
create policy "visited_migration_state_insert_own"
on public.visited_migration_state
for insert
with check (auth.uid() = user_id);

drop policy if exists "visited_migration_state_update_own" on public.visited_migration_state;
create policy "visited_migration_state_update_own"
on public.visited_migration_state
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop trigger if exists set_visited_migration_state_updated_at on public.visited_migration_state;
create trigger set_visited_migration_state_updated_at
before update on public.visited_migration_state
for each row
execute function public.set_current_timestamp_updated_at();
```

### 2. RPC: `get_visited_migration_state`
```sql
create or replace function public.get_visited_migration_state()
returns jsonb
language plpgsql
security invoker
as $$
declare
    current_state public.visited_migration_state;
begin
    select *
    into current_state
    from public.visited_migration_state
    where user_id = auth.uid();

    if current_state is null then
        return jsonb_build_object(
            'bootstrap_required', true,
            'bootstrapped_at', null,
            'bootstrap_source', null
        );
    end if;

    return jsonb_build_object(
        'bootstrap_required', not current_state.bootstrap_completed,
        'bootstrapped_at', current_state.bootstrapped_at,
        'bootstrap_source', current_state.bootstrap_source
    );
end;
$$;
```

### 3. RPC: `bootstrap_visited_from_app`
```sql
create or replace function public.bootstrap_visited_from_app(
    source text,
    replace_existing boolean,
    items jsonb
)
returns jsonb
language plpgsql
security invoker
as $$
declare
    item jsonb;
    item_count integer := 0;
    current_user uuid := auth.uid();
    existing_state public.visited_migration_state;
    bootstrapped_at_value timestamptz := timezone('utc', now());
begin
    if current_user is null then
        raise exception 'auth required';
    end if;

    if replace_existing is distinct from true then
        raise exception 'replace_existing must be true in v1 bootstrap';
    end if;

    if items is null or jsonb_typeof(items) <> 'array' then
        raise exception 'items must be a json array';
    end if;

    select *
    into existing_state
    from public.visited_migration_state
    where user_id = current_user;

    if existing_state.bootstrap_completed is true then
        raise exception using errcode = '23505', message = 'bootstrap already completed';
    end if;

    delete from public.visited
    where user_id = current_user;

    for item in select * from jsonb_array_elements(items)
    loop
        if not (item ? 'club_id') then
            raise exception 'each item must contain club_id';
        end if;

        insert into public.visited (
            user_id,
            club_id,
            visited,
            visited_date,
            source
        )
        values (
            current_user,
            item->>'club_id',
            coalesce((item->>'visited')::boolean, false),
            case
                when item->>'visited_date' is null or item->>'visited_date' = '' then null
                else (item->>'visited_date')::timestamptz
            end,
            source
        );

        item_count := item_count + 1;
    end loop;

    insert into public.visited_migration_state (
        user_id,
        bootstrap_completed,
        bootstrap_source,
        bootstrapped_at
    )
    values (
        current_user,
        true,
        source,
        bootstrapped_at_value
    )
    on conflict (user_id)
    do update set
        bootstrap_completed = true,
        bootstrap_source = excluded.bootstrap_source,
        bootstrapped_at = excluded.bootstrapped_at,
        updated_at = timezone('utc', now());

    return jsonb_build_object(
        'bootstrapped', true,
        'bootstrap_source', source,
        'bootstrapped_at', bootstrapped_at_value,
        'item_count', item_count
    );
end;
$$;
```

### 4. Hurtig verifikation
Kør disse bagefter:

```sql
select public.get_visited_migration_state();
```

```sql
select *
from public.visited_migration_state
order by updated_at desc
limit 20;
```

```sql
select user_id, count(*)
from public.visited
group by user_id
order by count(*) desc
limit 20;
```

### 5. Praktisk testsekvens
1. log ind på web og app med samme bruger
2. sørg for at appen stadig har sit lokale snapshot
3. log ind i appen
4. bekræft bootstrap-advarslen
5. verificér at `visited_migration_state.bootstrap_completed = true`
6. refresh web og kontrollér at visited nu matcher appens snapshot
Undgå at:
- migrere app og web samtidig
- fjerne `visits` samme dag som `visited` introduceres
- ændre UI og datamodel i samme deploy

## Næste konkrete kodearbejde
Når schemaet er oprettet i Supabase, bør næste kodeændring være:
- verificere at repository faktisk bruger `visited`
- derefter fjerne fallback til `visits`, når du er komfortabel med migrationen
