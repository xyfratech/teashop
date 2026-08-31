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
