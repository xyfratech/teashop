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
