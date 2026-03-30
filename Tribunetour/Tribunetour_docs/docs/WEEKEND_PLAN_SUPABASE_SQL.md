# Weekend Plan Supabase SQL

## Tabel

```sql
create table if not exists public.weekend_plans (
  user_id uuid primary key references auth.users(id) on delete cascade,
  fixture_ids text[] not null default '{}',
  updated_at timestamptz not null default timezone('utc', now()),
  source text not null default 'web'
);
```

## RLS

```sql
alter table public.weekend_plans enable row level security;
```

```sql
create policy weekend_plans_select_own
on public.weekend_plans
for select
to authenticated
using (auth.uid() = user_id);
```

```sql
create policy weekend_plans_insert_own
on public.weekend_plans
for insert
to authenticated
with check (auth.uid() = user_id);
```

```sql
create policy weekend_plans_update_own
on public.weekend_plans
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

```sql
create policy weekend_plans_delete_own
on public.weekend_plans
for delete
to authenticated
using (auth.uid() = user_id);
```

## Verificering

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'weekend_plans'
order by ordinal_position;
```

```sql
select policyname, cmd, permissive
from pg_policies
where schemaname = 'public'
  and tablename = 'weekend_plans'
order by policyname;
```
