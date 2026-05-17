-- =============================================================================
-- Legal AI Backend — Supabase / Postgres schema (single file)
-- Paste into Supabase SQL Editor and run. Safe to re-run (idempotent).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extensions
-- -----------------------------------------------------------------------------
-- UUIDs use built-in gen_random_uuid() (PG 13+); no pgcrypto required.
-- Supabase hosts pgvector in the extensions schema — required for vector(...) type + operators.
create extension if not exists vector with schema extensions;

-- -----------------------------------------------------------------------------
-- 2. Enums + helpers
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role' and typnamespace = (select oid from pg_namespace where nspname = 'public')) then
    create type public.user_role as enum ('user', 'admin');
  end if;
  if not exists (select 1 from pg_type where typname = 'message_role' and typnamespace = (select oid from pg_namespace where nspname = 'public')) then
    create type public.message_role as enum ('user', 'assistant');
  end if;
  if not exists (select 1 from pg_type where typname = 'subscription_plan' and typnamespace = (select oid from pg_namespace where nspname = 'public')) then
    create type public.subscription_plan as enum ('free', 'pro', 'ultra');
  end if;
  if not exists (select 1 from pg_type where typname = 'subscription_status' and typnamespace = (select oid from pg_namespace where nspname = 'public')) then
    create type public.subscription_status as enum ('pending', 'active', 'on_hold', 'cancelled', 'expired', 'failed');
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Defined as plpgsql (not sql) so the reference to public.profiles is resolved
-- lazily at first call, letting this run before the profiles table is created.
create or replace function public.is_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
end;
$$;

-- Prevent non-admins from changing role or is_active on profiles.
create or replace function public.enforce_profiles_admin_only_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (old.role is distinct from new.role or old.is_active is distinct from new.is_active)
     and not public.is_admin() then
    raise exception 'Only administrators may change profile role or is_active';
  end if;
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. profiles
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text,
  role public.user_role not null default 'user'::public.user_role,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles(role);

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists profiles_enforce_admin_fields_trg on public.profiles;
create trigger profiles_enforce_admin_fields_trg
before update on public.profiles
for each row execute procedure public.enforce_profiles_admin_only_fields();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name'
    )
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 4. user_subscriptions
-- -----------------------------------------------------------------------------
create table if not exists public.user_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  dodo_customer_id text unique,
  dodo_subscription_id text unique,
  dodo_product_id text,
  plan public.subscription_plan not null default 'free'::public.subscription_plan,
  status public.subscription_status not null default 'pending'::public.subscription_status,
  current_period_end timestamptz,
  cancel_at_next_billing_date boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_subscriptions_customer_idx
  on public.user_subscriptions(dodo_customer_id)
  where dodo_customer_id is not null;

create index if not exists user_subscriptions_status_idx
  on public.user_subscriptions(status);

drop trigger if exists user_subscriptions_set_updated_at on public.user_subscriptions;
create trigger user_subscriptions_set_updated_at
before update on public.user_subscriptions
for each row execute procedure public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 5. chat_threads
-- -----------------------------------------------------------------------------
create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'New chat',
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists chat_threads_user_active_idx
  on public.chat_threads(user_id, updated_at desc)
  where not is_deleted;

drop trigger if exists chat_threads_set_updated_at on public.chat_threads;
create trigger chat_threads_set_updated_at
before update on public.chat_threads
for each row execute procedure public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 6. chat_messages
-- -----------------------------------------------------------------------------
create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.message_role not null,
  content text not null,
  sources jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_thread_idx on public.chat_messages(thread_id, created_at);
create index if not exists chat_messages_user_idx on public.chat_messages(user_id);

-- Overwrite provided user_id with thread owner so clients cannot spoof RLS subject.
create or replace function public.chat_messages_set_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select t.user_id into new.user_id
  from public.chat_threads as t
  where t.id = new.thread_id;

  if new.user_id is null then
    raise exception 'thread_id % does not exist', new.thread_id;
  end if;

  return new;
end;
$$;

drop trigger if exists chat_messages_set_owner_trg on public.chat_messages;
create trigger chat_messages_set_owner_trg
before insert on public.chat_messages
for each row execute procedure public.chat_messages_set_owner();

-- Sidebar ordering: bump thread.updated_at when a message is added.
create or replace function public.chat_threads_touch_on_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_threads
  set updated_at = now()
  where id = new.thread_id;

  return new;
end;
$$;

drop trigger if exists chat_threads_touch_after_message_ins on public.chat_messages;
create trigger chat_threads_touch_after_message_ins
after insert on public.chat_messages
for each row execute procedure public.chat_threads_touch_on_message();

-- -----------------------------------------------------------------------------
-- 7. legal_documents (one row per chunk)
-- -----------------------------------------------------------------------------
create table if not exists public.legal_documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  embedding extensions.vector(768) not null,
  is_in_effect boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists legal_documents_in_effect_idx on public.legal_documents(is_in_effect);

create index if not exists legal_documents_metadata_idx
  on public.legal_documents using gin (metadata);

create index if not exists legal_documents_embedding_hnsw
  on public.legal_documents using hnsw (embedding extensions.vector_cosine_ops);

drop trigger if exists legal_documents_set_updated_at on public.legal_documents;
create trigger legal_documents_set_updated_at
before update on public.legal_documents
for each row execute procedure public.set_updated_at();

-- -----------------------------------------------------------------------------
-- 8. RAG: match_documents RPC
-- -----------------------------------------------------------------------------
create or replace function public.match_documents(
  query_embedding extensions.vector(768),
  match_count int default 8,
  only_in_effect boolean default true,
  filter jsonb default '{}'::jsonb
)
returns table (
  id uuid,
  title text,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  return query
  select
    d.id,
    d.title,
    d.content,
    d.metadata,
    (1 - (d.embedding <=> query_embedding))::float as similarity
  from public.legal_documents as d
  where (not only_in_effect or d.is_in_effect)
    and (filter = '{}'::jsonb or d.metadata @> filter)
  order by d.embedding <=> query_embedding
  limit least(greatest(match_count, 1), 50);
end;
$$;

-- -----------------------------------------------------------------------------
-- 9. Row Level Security
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.user_subscriptions enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.legal_documents enable row level security;

-- profiles
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin
  on public.profiles
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- user_subscriptions (users can read only their own billing state; writes are service-role only)
drop policy if exists user_subscriptions_select_self_or_admin on public.user_subscriptions;
create policy user_subscriptions_select_self_or_admin
  on public.user_subscriptions
  for select
  to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- chat_threads (strict: owner only; no admin read)
drop policy if exists chat_threads_all_owner on public.chat_threads;
create policy chat_threads_all_owner
  on public.chat_threads
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- chat_messages
drop policy if exists chat_messages_select_owner on public.chat_messages;
create policy chat_messages_select_owner
  on public.chat_messages
  for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists chat_messages_insert_owner on public.chat_messages;
create policy chat_messages_insert_owner
  on public.chat_messages
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.chat_threads as t
      where t.id = thread_id
        and t.user_id = auth.uid()
    )
  );

drop policy if exists chat_messages_delete_owner on public.chat_messages;
create policy chat_messages_delete_owner
  on public.chat_messages
  for delete
  to authenticated
  using (user_id = auth.uid());

-- legal_documents: read for any signed-in user; write for admins only
drop policy if exists legal_documents_select_authenticated on public.legal_documents;
drop policy if exists legal_documents_insert_admin on public.legal_documents;
drop policy if exists legal_documents_update_admin on public.legal_documents;
drop policy if exists legal_documents_delete_admin on public.legal_documents;
drop policy if exists legal_documents_write_admin on public.legal_documents;

create policy legal_documents_select_authenticated
  on public.legal_documents
  for select
  to authenticated
  using (true);

create policy legal_documents_insert_admin
  on public.legal_documents
  for insert
  to authenticated
  with check (public.is_admin());

create policy legal_documents_update_admin
  on public.legal_documents
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy legal_documents_delete_admin
  on public.legal_documents
  for delete
  to authenticated
  using (public.is_admin());

-- -----------------------------------------------------------------------------
-- 10. Grants (RPC + helper for PostgREST)
-- -----------------------------------------------------------------------------
grant usage on schema public to authenticated;
grant usage on schema extensions to authenticated;

grant select, update on public.profiles to authenticated;
grant select on public.user_subscriptions to authenticated;
grant select, insert, update, delete on public.chat_threads to authenticated;
grant select, insert, delete on public.chat_messages to authenticated;
grant select, insert, update, delete on public.legal_documents to authenticated;

grant execute on function public.is_admin() to authenticated;

do $$
declare
  fn_oid oid;
begin
  select p.oid
    into fn_oid
  from pg_catalog.pg_proc as p
  join pg_catalog.pg_namespace as n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'match_documents';

  if fn_oid is not null then
    execute format(
      'grant execute on function %s to authenticated',
      fn_oid::regprocedure::text
    );
  end if;
end
$$;
