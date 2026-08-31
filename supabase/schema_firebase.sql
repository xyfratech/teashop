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
  p_owner_name text default null, p_trial_days int default 14
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
    now() + make_interval(days => greatest(coalesce(p_trial_days, 14), 0)),
    now() + make_interval(days => greatest(coalesce(p_trial_days, 14), 0))
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
