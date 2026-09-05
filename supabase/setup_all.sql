-- ============================================================================
--  Tea Shop Manager — COMPLETE database setup (run once, top to bottom)
--
--  HOW TO RUN:
--    Supabase dashboard  ->  project 'tea shop'  ->  SQL Editor (left rail)
--    ->  '+ New query'  ->  paste this whole file  ->  Run.
--
--  This is schema_firebase.sql + ledger_schema.sql + income_expense_profit_views.sql
--  concatenated in dependency order. Every statement is idempotent, so it is
--  safe to run again after an error or a change.
--  Generated 2026-08-31T14:51:28Z — do not edit; edit the source files.
-- ============================================================================


-- >>>>>>>>>>>>>>>>>>>>  1/3  schema_firebase.sql  <<<<<<<<<<<<<<<<<<<<

-- =====================================================================
-- Tea Shop Manager — full backend schema (Firebase Phone-OTP edition)
-- Run this once on the app's Supabase project. Safe to re-run.
--
-- Everyone signs in with phone number + OTP (Firebase Phone Auth). Every
-- request carries the Firebase ID token, which this project trusts
-- (Dashboard → Authentication → Third-Party Auth → Firebase, project id
-- `tea-shop-798ea`). Claims used:
--   auth.jwt() ->> 'sub'          → Firebase UID  (public.fb_uid())
--   auth.jwt() ->> 'phone_number' → E.164 phone   (public.fb_phone())
-- =====================================================================

-- ---------- tables ----------
create table if not exists public.shops (
  id            uuid primary key default gen_random_uuid(),
  user_id       text unique,                    -- Firebase UID (null until owner activates)
  username      text,                           -- display label the admin set
  phone         text,                           -- owner signs in with this (E.164)
  name          text not null default 'My Tea Shop',
  owner_name    text,
  plan          text not null default 'basic_49',
  created_at    timestamptz not null default now(),
  trial_ends_at timestamptz not null default now() + interval '14 days',
  expires_at    timestamptz not null default now() + interval '14 days',
  is_blocked    boolean not null default false,
  last_seen_at  timestamptz,
  app_version   text,
  admin_note    text,
  updated_at    timestamptz not null default now()
);

alter table public.shops add column if not exists username text;
alter table public.shops add column if not exists phone    text;

create unique index if not exists shops_username_key
  on public.shops (lower(username)) where username is not null;
create unique index if not exists shops_phone_key
  on public.shops (phone) where phone is not null;

create table if not exists public.admin_users (
  user_id    text primary key,                  -- Firebase UID of the admin
  phone      text,
  username   text,
  email      text,
  created_at timestamptz not null default now()
);
alter table public.admin_users add column if not exists phone    text;
alter table public.admin_users add column if not exists username text;

alter table public.shops       enable row level security;
alter table public.admin_users enable row level security;

-- ---------- helpers ----------
create or replace function public.fb_uid()
returns text language sql stable as $$
  select nullif(auth.jwt() ->> 'sub', '')
$$;

create or replace function public.fb_phone()
returns text language sql stable as $$
  select nullif(auth.jwt() ->> 'phone_number', '')
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (select 1 from public.admin_users a where a.user_id = public.fb_uid());
$$;

create or replace function public.admin_exists()
returns boolean language sql stable security definer set search_path to 'public'
as $$
  select exists (select 1 from public.admin_users);
$$;

-- ---------- shop-owner facing ----------

-- The login id the caller's Firebase account was created with
-- (email is `<id>@tsm.local`).
create or replace function public.fb_login_id()
returns text language sql stable as $$
  select lower(nullif(split_part(auth.jwt() ->> 'email', '@', 1), ''))
$$;

-- Claims the sole admin row — only for the preset admin login id, and only
-- once. Change 'adm1234' here AND SupabaseConfig.adminLoginId (lower-cased).
create or replace function public.claim_first_admin()
returns boolean language plpgsql security definer set search_path to 'public'
as $$
begin
  if public.fb_uid() is null then raise exception 'not authenticated'; end if;
  if public.fb_login_id() is distinct from 'adm1234' then
    raise exception 'not the admin login id';
  end if;
  -- ADM1234 is authoritative: it (re)claims the admin row, taking it over
  -- from any stale UID left by an earlier build.
  delete from public.admin_users where user_id <> public.fb_uid();
  insert into public.admin_users (user_id, username)
  values (public.fb_uid(), 'adm1234')
  on conflict (user_id) do nothing;
  return true;
end;
$$;

-- Returns the caller's shop by Firebase UID (null if not linked yet).
create or replace function public.my_shop()
returns public.shops language plpgsql stable security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  select * into result from public.shops where user_id = public.fb_uid();
  return result;
end;
$$;

-- One-time activation: link a pending shop (user_id null) whose login id
-- matches, then return it. Also returns an already-linked shop.
create or replace function public.claim_shop_by_login(p_login_id text)
returns public.shops language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  select * into result from public.shops where user_id = public.fb_uid();
  if result.id is not null then return result; end if;

  update public.shops
     set user_id = public.fb_uid(), last_seen_at = now()
   where user_id is null
     and username is not null
     and lower(username) = lower(trim(p_login_id))
   returning * into result;
  return result;
end;
$$;

create or replace function public.shop_heartbeat(p_app_version text default null)
returns public.shops language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  update public.shops
     set last_seen_at = now(),
         app_version = coalesce(nullif(trim(p_app_version), ''), app_version)
   where user_id = public.fb_uid()
   returning * into result;
  return result;
end;
$$;

-- ---------- admin facing ----------
create or replace function public.admin_list_shops()
returns setof public.shops language plpgsql stable security definer set search_path to 'public'
as $$
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  return query select * from public.shops order by expires_at asc;
end;
$$;

-- Register a pending shop under a login id (no Firebase account yet — the
-- shop links to whoever first signs in with that id).
create or replace function public.admin_register_shop(
  p_login_id text, p_name text,
  p_owner_name text default null, p_trial_days int default 7
) returns public.shops
language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  if coalesce(trim(p_login_id), '') = '' then raise exception 'login id required'; end if;
  if lower(trim(p_login_id)) = 'adm1234' then raise exception 'that id is reserved'; end if;
  if exists (select 1 from public.shops where lower(username) = lower(trim(p_login_id))) then
    raise exception 'login id "%" is already used', trim(p_login_id);
  end if;
  insert into public.shops (user_id, username, name, owner_name,
                            trial_ends_at, expires_at)
  values (
    null,
    trim(p_login_id),
    coalesce(nullif(trim(p_name), ''), 'My Tea Shop'),
    nullif(trim(p_owner_name), ''),
    now() + make_interval(days => greatest(coalesce(p_trial_days, 7), 0)),
    now() + make_interval(days => greatest(coalesce(p_trial_days, 7), 0))
  )
  returning * into result;
  return result;
end;
$$;

drop function if exists public.admin_create_shop(text, text, text, text, int);
drop function if exists public.admin_register_shop(text, text, text, text, int);

create or replace function public.admin_extend_shop(p_shop_id uuid, p_months integer default 1)
returns public.shops language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  update public.shops
     set expires_at = greatest(expires_at, now()) + make_interval(months => greatest(coalesce(p_months, 1), 1)),
         is_blocked = false
   where id = p_shop_id
   returning * into result;
  if result.id is null then raise exception 'shop not found'; end if;
  return result;
end;
$$;

create or replace function public.admin_set_expiry(p_shop_id uuid, p_expires_at timestamptz)
returns public.shops language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  update public.shops set expires_at = p_expires_at
   where id = p_shop_id returning * into result;
  if result.id is null then raise exception 'shop not found'; end if;
  return result;
end;
$$;

create or replace function public.admin_set_blocked(p_shop_id uuid, p_blocked boolean)
returns public.shops language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  update public.shops set is_blocked = coalesce(p_blocked, false)
   where id = p_shop_id returning * into result;
  if result.id is null then raise exception 'shop not found'; end if;
  return result;
end;
$$;

create or replace function public.admin_set_note(p_shop_id uuid, p_note text)
returns public.shops language plpgsql security definer set search_path to 'public'
as $$
declare result public.shops;
begin
  if not public.is_admin() then raise exception 'not authorized'; end if;
  update public.shops set admin_note = p_note
   where id = p_shop_id returning * into result;
  if result.id is null then raise exception 'shop not found'; end if;
  return result;
end;
$$;

-- ---------- triggers ----------
create or replace function public.shops_before_insert()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if not public.is_admin() and new.user_id is distinct from public.fb_uid() then
    raise exception 'not authorized';
  end if;
  new.plan := coalesce(nullif(new.plan, ''), 'basic_49');
  new.created_at := coalesce(new.created_at, now());
  new.trial_ends_at := coalesce(new.trial_ends_at, now() + interval '14 days');
  new.expires_at := coalesce(new.expires_at, now() + interval '14 days');
  new.is_blocked := coalesce(new.is_blocked, false);
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.shops_before_update()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  new.updated_at := now();
  if public.is_admin() then return new; end if;

  -- A non-admin may never change the billing / identity columns...
  new.username      := old.username;
  new.phone         := old.phone;
  new.plan          := old.plan;
  new.created_at    := old.created_at;
  new.trial_ends_at := old.trial_ends_at;
  new.expires_at    := old.expires_at;
  new.is_blocked    := old.is_blocked;
  new.admin_note    := old.admin_note;

  -- ...and user_id is write-once: allowed only to go from null to a value
  -- (the owner activating their pre-registered shop).
  if old.user_id is not null then
    new.id      := old.id;
    new.user_id := old.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists shops_before_insert on public.shops;
create trigger shops_before_insert before insert on public.shops
  for each row execute function public.shops_before_insert();

drop trigger if exists shops_before_update on public.shops;
create trigger shops_before_update before update on public.shops
  for each row execute function public.shops_before_update();

-- ---------- RLS policies ----------
drop policy if exists "shop reads own or admin reads all" on public.shops;
drop policy if exists "insert own or admin"               on public.shops;
drop policy if exists "update own or admin"               on public.shops;
drop policy if exists "admin deletes"                     on public.shops;

create policy "shop reads own or admin reads all" on public.shops for select
  using (user_id = public.fb_uid() or public.is_admin());
create policy "insert own or admin" on public.shops for insert
  with check (user_id = public.fb_uid() or public.is_admin());
create policy "update own or admin" on public.shops for update
  using (user_id = public.fb_uid() or public.is_admin())
  with check (user_id = public.fb_uid() or public.is_admin());
create policy "admin deletes" on public.shops for delete
  using (public.is_admin());

drop policy if exists "see admin rows" on public.admin_users;
create policy "see admin rows" on public.admin_users for select
  using (user_id = public.fb_uid() or public.is_admin());

-- ---------- grants ----------
grant usage on schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;


-- >>>>>>>>>>>>>>>>>>>>  2/3  ledger_schema.sql  <<<<<<<<<<<<<<<<<<<<

-- ============================================================================
--  Tea Shop Manager — cloud ledger (income + expense) + reporting views
--
--  Run AFTER supabase/schema_firebase.sql (it needs public.fb_uid() and
--  public.is_admin()). Safe to re-run — every statement is idempotent.
--
--  There is ONE ledger table: public.transactions. Each row is a single money
--  movement the app saved on a device — an income row (a sale) or an expense
--  row (a purchase / bill). "Profit" is never stored; it is income - expense,
--  computed by the summary views at the bottom.
--
--  Column-for-column this mirrors what the app sends:
--    AppState.ledgerRow(Txn)  ->  id, type, amount, category_id, category_name,
--                                 product_id, product_name, note, qty, method,
--                                 occurred_at, deleted
--    LedgerSync.flush()       ->  client_id, shop_id, shop_name, updated_at
--    transactions_stamp()     ->  user_id (Firebase UID), created_at, updated_at
--
--  Ownership: user_id is stamped server-side from the Firebase token, so it
--  cannot be spoofed. The owner reads back their own rows; the admin reads
--  everyone's for reporting.
-- ============================================================================

-- ----------------------------------------------------------------------------
--  Table
-- ----------------------------------------------------------------------------
create table if not exists public.transactions (
  id            uuid           primary key,       -- Txn.id (client-generated v4)
  user_id       text,                             -- Firebase UID of the owner (set by trigger)
  client_id     uuid,                             -- per-install id, for debugging
  shop_id       uuid,                             -- public.shops.id of the signed-in shop
  shop_name     text,                             -- display name at time of sync
  type          text           not null,          -- 'income' | 'expense'
  amount        numeric(12, 2) not null,          -- total money moved, always >= 0
  category_id   text,                             -- Category.id (client-generated v4)
  category_name text,                             -- denormalised label, e.g. 'Tea Sales'
  product_id    text,                             -- Product.id when the row is a menu-item sale
  product_name  text,                             -- denormalised label, e.g. 'Regular Tea'
  note          text           not null default '',
  qty           integer        not null default 1,-- units sold (Txn.quantity)
  method        text,                             -- 'cash' | 'upi' | 'card' | 'other'
  occurred_at   timestamptz    not null,          -- Txn.date (when the money moved)
  created_at    timestamptz    not null default now(),
  updated_at    timestamptz    not null default now(),
  deleted       boolean        not null default false  -- soft delete (tombstone)
);

-- Bring a table created by an older schema up to the current column set.
alter table public.transactions add column if not exists user_id      text;
alter table public.transactions add column if not exists client_id    uuid;
alter table public.transactions add column if not exists shop_id      uuid;
alter table public.transactions add column if not exists shop_name    text;
alter table public.transactions add column if not exists category_id  text;
alter table public.transactions add column if not exists category_name text;
alter table public.transactions add column if not exists product_id   text;
alter table public.transactions add column if not exists product_name text;
alter table public.transactions add column if not exists note         text        not null default '';
alter table public.transactions add column if not exists qty          integer     not null default 1;
alter table public.transactions add column if not exists method       text;
alter table public.transactions add column if not exists created_at   timestamptz not null default now();
alter table public.transactions add column if not exists updated_at   timestamptz not null default now();
alter table public.transactions add column if not exists deleted      boolean     not null default false;

-- ----------------------------------------------------------------------------
--  Constraints (added idempotently — Postgres has no ADD CONSTRAINT IF NOT EXISTS)
-- ----------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'transactions_type_chk') then
    alter table public.transactions
      add constraint transactions_type_chk check (type in ('income', 'expense'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'transactions_method_chk') then
    alter table public.transactions
      add constraint transactions_method_chk
      check (method is null or method in ('cash', 'upi', 'card', 'other'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'transactions_amount_chk') then
    alter table public.transactions
      add constraint transactions_amount_chk check (amount >= 0);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'transactions_qty_chk') then
    alter table public.transactions
      add constraint transactions_qty_chk check (qty >= 0);
  end if;

  -- shop_id points at a real shop when set. NOT VALID so a re-run never fails
  -- on rows that pre-date the constraint; new / updated rows are still checked.
  if not exists (select 1 from pg_constraint where conname = 'transactions_shop_id_fkey') then
    alter table public.transactions
      add constraint transactions_shop_id_fkey
      foreign key (shop_id) references public.shops (id) on delete set null not valid;
  end if;
end $$;

-- ----------------------------------------------------------------------------
--  Indexes
-- ----------------------------------------------------------------------------
create index if not exists transactions_user_id_idx        on public.transactions (user_id);
create index if not exists transactions_shop_id_idx        on public.transactions (shop_id);
create index if not exists transactions_occurred_at_idx    on public.transactions (occurred_at);
create index if not exists transactions_user_occurred_idx  on public.transactions (user_id, occurred_at desc);
create index if not exists transactions_category_id_idx    on public.transactions (category_id);
create index if not exists transactions_live_idx           on public.transactions (user_id, shop_id, occurred_at)
  where not deleted;

-- ----------------------------------------------------------------------------
--  Stamp owner + timestamps server-side
-- ----------------------------------------------------------------------------
create or replace function public.transactions_stamp()
returns trigger language plpgsql security definer set search_path to 'public'
as $$
begin
  if public.fb_uid() is not null then
    new.user_id := public.fb_uid();
  end if;
  new.updated_at := now();
  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_stamp on public.transactions;
create trigger transactions_stamp before insert or update on public.transactions
  for each row execute function public.transactions_stamp();

-- ----------------------------------------------------------------------------
--  Row-level security
-- ----------------------------------------------------------------------------
alter table public.transactions enable row level security;

-- Old anon push-only policies — gone.
drop policy if exists transactions_anon_insert on public.transactions;
drop policy if exists transactions_anon_update on public.transactions;

drop policy if exists transactions_owner_rw   on public.transactions;
drop policy if exists transactions_admin_read on public.transactions;

create policy transactions_owner_rw
  on public.transactions
  for all
  using (user_id = public.fb_uid())
  with check (user_id = public.fb_uid() or user_id is null);

create policy transactions_admin_read
  on public.transactions
  for select
  using (public.is_admin());

-- ----------------------------------------------------------------------------
--  Shop profile + settings fields (kept on the existing shops row).
--  Must come BEFORE the views below — public.shop_totals reads
--  shops.opening_balance.
-- ----------------------------------------------------------------------------
alter table public.shops add column if not exists address         text;
alter table public.shops add column if not exists contact_phone   text;
alter table public.shops add column if not exists gst_number      text;
alter table public.shops add column if not exists logo_url        text;
alter table public.shops add column if not exists currency        text           not null default '₹';
alter table public.shops add column if not exists opening_balance numeric(12, 2)  not null default 0;

-- ============================================================================
--  Reporting views  (security_invoker => the caller's RLS applies, so an owner
--  sees only their own figures and the admin sees every shop)
-- ============================================================================

-- ---- Per-day income / expense / profit -------------------------------------
drop view if exists public.daily_summary;
create view public.daily_summary
with (security_invoker = true) as
select
  user_id,
  shop_id,
  max(shop_name)                                                          as shop_name,
  date_trunc('day', occurred_at)                                          as day,
  count(*) filter (where type = 'income')                                 as income_count,
  count(*) filter (where type = 'expense')                                as expense_count,
  coalesce(sum(amount) filter (where type = 'income'),  0)                as income,
  coalesce(sum(amount) filter (where type = 'expense'), 0)                as expense,
  coalesce(sum(amount) filter (where type = 'income'),  0)
    - coalesce(sum(amount) filter (where type = 'expense'), 0)            as profit
from public.transactions
where not deleted
group by user_id, shop_id, date_trunc('day', occurred_at);

-- ---- Per-month income / expense / profit (Reports screen, 6-month chart) ---
drop view if exists public.monthly_summary;
create view public.monthly_summary
with (security_invoker = true) as
select
  user_id,
  shop_id,
  max(shop_name)                                                          as shop_name,
  date_trunc('month', occurred_at)                                        as month,
  count(*) filter (where type = 'income')                                 as income_count,
  count(*) filter (where type = 'expense')                                as expense_count,
  coalesce(sum(amount) filter (where type = 'income'),  0)                as income,
  coalesce(sum(amount) filter (where type = 'expense'), 0)                as expense,
  coalesce(sum(amount) filter (where type = 'income'),  0)
    - coalesce(sum(amount) filter (where type = 'expense'), 0)            as profit
from public.transactions
where not deleted
group by user_id, shop_id, date_trunc('month', occurred_at);

-- ---- Per-category totals per month (category breakdown pies) --------------
drop view if exists public.category_summary;
create view public.category_summary
with (security_invoker = true) as
select
  user_id,
  shop_id,
  date_trunc('month', occurred_at)                                        as month,
  type,
  category_id,
  max(category_name)                                                      as category_name,
  count(*)                                                                as entry_count,
  coalesce(sum(amount), 0)                                                as total,
  coalesce(sum(qty), 0)                                                   as qty
from public.transactions
where not deleted
group by user_id, shop_id, date_trunc('month', occurred_at), type, category_id;

-- ---- Per-payment-method totals per month --------------------------------
drop view if exists public.method_summary;
create view public.method_summary
with (security_invoker = true) as
select
  user_id,
  shop_id,
  date_trunc('month', occurred_at)                                        as month,
  type,
  coalesce(method, 'other')                                              as method,
  count(*)                                                                as entry_count,
  coalesce(sum(amount), 0)                                                as total
from public.transactions
where not deleted
group by user_id, shop_id, date_trunc('month', occurred_at), type, coalesce(method, 'other');

-- ---- Per-product sales totals (menu performance / margin) --------------
drop view if exists public.product_summary;
create view public.product_summary
with (security_invoker = true) as
select
  user_id,
  shop_id,
  date_trunc('month', occurred_at)                                        as month,
  product_id,
  max(product_name)                                                      as product_name,
  count(*)                                                                as sale_count,
  coalesce(sum(qty), 0)                                                   as units_sold,
  coalesce(sum(amount), 0)                                                as revenue
from public.transactions
where not deleted and type = 'income' and product_id is not null
group by user_id, shop_id, date_trunc('month', occurred_at), product_id;

-- ---- All-time totals + running balance per shop -----------------------
--  Mirrors AppState: balance = opening_balance + total_income - total_expense.
drop view if exists public.shop_totals;
create view public.shop_totals
with (security_invoker = true) as
select
  t.user_id,
  t.shop_id,
  max(t.shop_name)                                                        as shop_name,
  coalesce(s.opening_balance, 0)                                          as opening_balance,
  count(*) filter (where t.type = 'income')                               as income_count,
  count(*) filter (where t.type = 'expense')                              as expense_count,
  coalesce(sum(t.amount) filter (where t.type = 'income'),  0)            as total_income,
  coalesce(sum(t.amount) filter (where t.type = 'expense'), 0)            as total_expense,
  coalesce(sum(t.amount) filter (where t.type = 'income'),  0)
    - coalesce(sum(t.amount) filter (where t.type = 'expense'), 0)        as total_profit,
  coalesce(s.opening_balance, 0)
    + coalesce(sum(t.amount) filter (where t.type = 'income'),  0)
    - coalesce(sum(t.amount) filter (where t.type = 'expense'), 0)        as balance,
  min(t.occurred_at)                                                      as first_entry_at,
  max(t.occurred_at)                                                      as last_entry_at
from public.transactions t
left join public.shops s on s.id = t.shop_id
where not t.deleted
group by t.user_id, t.shop_id, s.opening_balance;

grant select on
  public.transactions,
  public.daily_summary,
  public.monthly_summary,
  public.category_summary,
  public.method_summary,
  public.product_summary,
  public.shop_totals
to authenticated;


-- >>>>>>>>>>>>>>>>>>>>  3/3  income_expense_profit_views.sql  <<<<<<<<<<<<<<<<<<<<

-- ============================================================================
--  Tea Shop Manager — income / expence / profits  (VIEWS over transactions)
--
--  Run order:  schema_firebase.sql  ->  ledger_schema.sql  ->  THIS FILE
--  Safe to re-run: every object is dropped (as a view OR a leftover table)
--  before it is recreated.
--
--  WHY VIEWS, NOT TABLES
--  --------------------
--  The app writes every entry into ONE real table, public.transactions
--  (an "income" row = a sale, an "expense" row = a purchase / bill). These
--  three names are just filtered / rolled-up windows onto that table, so:
--    * they fill themselves the moment the app syncs — nothing to import,
--    * "profit" can never drift, it is always  income - expense,
--    * RLS on transactions still applies (security_invoker = true), so a shop
--      owner sees only their own figures and the admin sees every shop.
--  They are READ-ONLY. All data enters through public.transactions.
--
--  COLUMN SOURCE (income / expence rows mirror AppState.ledgerRow(Txn)):
--    id, type, amount, category_id, category_name, product_id, product_name,
--    note, qty, method, occurred_at, deleted        -- from the app
--    client_id, shop_id, shop_name, updated_at      -- added by LedgerSync
--    user_id (Firebase UID), created_at, updated_at -- stamped by the trigger
-- ============================================================================

-- Drop whichever kind of object currently holds each name — a hand-made
-- starter TABLE on the first run, one of these VIEWS on later runs.
-- (`drop view if exists` errors if the name is actually a table, and vice
-- versa, so decide from the catalog.)
do $$
declare r record;
begin
  for r in
    select c.relname, c.relkind
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relname in ('income', 'expence', 'profits')
  loop
    if r.relkind in ('v', 'm') then
      execute format('drop view if exists public.%I cascade', r.relname);
    else
      execute format('drop table if exists public.%I cascade', r.relname);
    end if;
  end loop;
end $$;

-- ----------------------------------------------------------------------------
--  income — one row per sale  (transactions.type = 'income', not deleted)
-- ----------------------------------------------------------------------------
create view public.income
with (security_invoker = true) as
select
  id,                       -- Txn.id (uuid, client-generated)
  user_id,                  -- Firebase UID of the shop owner
  client_id,                -- per-install id (diagnostics)
  shop_id,                  -- public.shops.id
  shop_name,                -- display name captured at sync time
  amount,                   -- money received (>= 0)
  category_id,
  category_name,            -- e.g. 'Tea Sales', 'Coffee Sales'
  product_id,               -- set when the sale is a menu item
  product_name,             -- e.g. 'Regular Tea'
  qty,                      -- units sold
  method,                   -- cash | upi | card | other
  note,
  occurred_at,              -- when the sale happened (Txn.date)
  created_at,
  updated_at
from public.transactions
where type = 'income'
  and not deleted;

-- ----------------------------------------------------------------------------
--  expence — one row per purchase / bill  (transactions.type = 'expense')
--  (spelling kept to match the table name the project was set up with)
-- ----------------------------------------------------------------------------
create view public.expence
with (security_invoker = true) as
select
  id,
  user_id,
  client_id,
  shop_id,
  shop_name,
  amount,                   -- money spent (>= 0)
  category_id,
  category_name,            -- e.g. 'Rent', 'Milk & Tea Leaves', 'Salaries'
  product_id,
  product_name,
  qty,
  method,
  note,
  occurred_at,              -- when the money was spent
  created_at,
  updated_at
from public.transactions
where type = 'expense'
  and not deleted;

-- ----------------------------------------------------------------------------
--  profits — per shop, per day: counts, income, expense, profit and the
--  running (cumulative) profit. profit = income - expense, exactly as the
--  app computes AppState.totalProfit. A `month` column is included so a
--  monthly report is just  ... group by month.
-- ----------------------------------------------------------------------------
create view public.profits
with (security_invoker = true) as
with per_day as (
  select
    user_id,
    shop_id,
    max(shop_name)                                            as shop_name,
    date_trunc('day', occurred_at)::date                      as day,
    count(*) filter (where type = 'income')                   as income_count,
    count(*) filter (where type = 'expense')                  as expense_count,
    coalesce(sum(amount) filter (where type = 'income'),  0)  as income,
    coalesce(sum(amount) filter (where type = 'expense'), 0)  as expense
  from public.transactions
  where not deleted
  group by user_id, shop_id, date_trunc('day', occurred_at)
)
select
  user_id,
  shop_id,
  shop_name,
  day,
  date_trunc('month', day::timestamp)::date as month,
  income_count,
  expense_count,
  income,
  expense,
  income - expense                        as profit,
  sum(income - expense) over (
    partition by user_id, shop_id
    order by day
    rows between unbounded preceding and current row
  )                                       as cumulative_profit
from per_day;

-- ----------------------------------------------------------------------------
--  Access: Firebase-authenticated users hit these as the `authenticated`
--  role; row visibility is still enforced by transactions' RLS.
-- ----------------------------------------------------------------------------
grant select on public.income, public.expence, public.profits to authenticated;

-- Make the new views show up in the REST API immediately.
notify pgrst, 'reload schema';
