-- Dodo Payments subscription state for web checkout, backend /auth/me, and
-- mobile plan display.
--
-- This matches the migration that was first applied manually in Supabase.
-- It is idempotent, but it does not need to be run again on that same database
-- unless you are applying the schema to another Supabase project.

begin;

do $$
begin
  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'subscription_plan'
      and n.nspname = 'public'
  ) then
    create type public.subscription_plan as enum ('free', 'pro', 'ultra');
  end if;

  if not exists (
    select 1 from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where t.typname = 'subscription_status'
      and n.nspname = 'public'
  ) then
    create type public.subscription_status as enum (
      'pending', 'active', 'on_hold', 'cancelled', 'expired', 'failed'
    );
  end if;
end
$$;

create table if not exists public.user_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table public.user_subscriptions
  add column if not exists dodo_customer_id text,
  add column if not exists dodo_subscription_id text,
  add column if not exists dodo_product_id text,
  add column if not exists plan public.subscription_plan not null default 'free'::public.subscription_plan,
  add column if not exists status public.subscription_status not null default 'pending'::public.subscription_status,
  add column if not exists current_period_end timestamptz,
  add column if not exists cancel_at_next_billing_date boolean not null default false,
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists user_subscriptions_dodo_customer_id_key
  on public.user_subscriptions(dodo_customer_id)
  where dodo_customer_id is not null;

create unique index if not exists user_subscriptions_dodo_subscription_id_key
  on public.user_subscriptions(dodo_subscription_id)
  where dodo_subscription_id is not null;

create index if not exists user_subscriptions_customer_idx
  on public.user_subscriptions(dodo_customer_id)
  where dodo_customer_id is not null;

create index if not exists user_subscriptions_status_idx
  on public.user_subscriptions(status);

drop trigger if exists user_subscriptions_set_updated_at on public.user_subscriptions;
create trigger user_subscriptions_set_updated_at
before update on public.user_subscriptions
for each row execute procedure public.set_updated_at();

alter table public.user_subscriptions enable row level security;

drop policy if exists user_subscriptions_select_self_or_admin on public.user_subscriptions;
create policy user_subscriptions_select_self_or_admin
  on public.user_subscriptions
  for select
  to authenticated
  using (user_id = auth.uid() or public.is_admin());

grant usage on schema public to authenticated;
grant select on public.user_subscriptions to authenticated;
grant all on public.user_subscriptions to service_role;

commit;
