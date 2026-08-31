-- Switch identity from Supabase Auth to Firebase Auth.
--
-- Every request from the app now carries a Firebase ID token, which this
-- project is configured to trust (Dashboard → Authentication → Third-Party
-- Auth → Firebase, project id `tea-shop-798ea`). The caller's Firebase UID is
-- `auth.jwt() ->> 'sub'` — a 28-char string, NOT a uuid, so we never use
-- `auth.uid()` (it casts to uuid and would throw).
--
-- `shops.user_id` and `admin_users.user_id` now hold that text UID.

-- 1. Drop the foreign keys to auth.users and widen the key columns to text.
alter table public.shops       drop constraint if exists shops_user_id_fkey;
alter table public.admin_users drop constraint if exists admin_users_user_id_fkey;

alter table public.shops       alter column user_id type text using user_id::text;
alter table public.admin_users alter column user_id type text using user_id::text;

-- 2. Human login id on the shop row + case-insensitive uniqueness.
alter table public.shops add column if not exists username text;
create unique index if not exists shops_username_key
  on public.shops (lower(username)) where username is not null;

-- 3. Helper: the caller's Firebase UID (null when unauthenticated).
create or replace function public.fb_uid()
returns text language sql stable as $function$
  select nullif(auth.jwt() ->> 'sub', '')
$function$;

-- 4. Role / ownership helpers.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path to 'public'
as $function$
  select exists (
    select 1 from public.admin_users a where a.user_id = public.fb_uid()
  );
$function$;

create or replace function public.admin_exists()
returns boolean language sql stable security definer set search_path to 'public'
as $function$
  select exists (select 1 from public.admin_users);
$function$;

create or replace function public.claim_first_admin()
returns boolean language plpgsql security definer set search_path to 'public'
as $function$
begin
  if public.fb_uid() is null then
    raise exception 'not authenticated';
  end if;
  if exists (select 1 from public.admin_users where user_id = public.fb_uid()) then
    return true;                                   -- already the admin: no-op
  end if;
  if exists (select 1 from public.admin_users) then
    raise exception 'an admin already exists';
  end if;
  insert into public.admin_users (user_id, email)
  values (public.fb_uid(), auth.jwt() ->> 'email');
  return true;
end;
$function$;

create or replace function public.my_shop()
returns public.shops
language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  result public.shops;
begin
  select * into result from public.shops where user_id = public.fb_uid();
  return result;
end;
$function$;

-- 5. Admin provisions a shop for a given Firebase UID.
create or replace function public.admin_create_shop(
  p_firebase_uid text,
  p_username text,
  p_name text,
  p_owner_name text default null,
  p_trial_days int default 14
) returns public.shops
language plpgsql security definer set search_path to 'public'
as $function$
declare
  result public.shops;
begin
  if not public.is_admin() then
    raise exception 'not authorized';
  end if;
  if coalesce(trim(p_firebase_uid), '') = '' then
    raise exception 'firebase uid required';
  end if;
  insert into public.shops (user_id, username, name, owner_name,
                            trial_ends_at, expires_at)
  values (
    p_firebase_uid,
    nullif(trim(p_username), ''),
    coalesce(nullif(trim(p_name), ''), 'My Tea Shop'),
    nullif(trim(p_owner_name), ''),
    now() + make_interval(days => greatest(coalesce(p_trial_days, 14), 0)),
    now() + make_interval(days => greatest(coalesce(p_trial_days, 14), 0))
  )
  returning * into result;
  return result;
end;
$function$;

-- 6. Heartbeat (Firebase-keyed).
create or replace function public.shop_heartbeat(p_app_version text default null)
returns public.shops
language plpgsql security definer set search_path to 'public'
as $function$
declare
  result public.shops;
begin
  update public.shops
     set last_seen_at = now(),
         app_version = coalesce(nullif(trim(p_app_version), ''), app_version)
   where user_id = public.fb_uid()
   returning * into result;
  return result;
end;
$function$;

-- 7. Triggers.
create or replace function public.shops_before_insert()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
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
$function$;

create or replace function public.shops_before_update()
returns trigger language plpgsql security definer set search_path to 'public'
as $function$
begin
  new.updated_at := now();
  if public.is_admin() then
    return new;
  end if;
  new.id := old.id;
  new.user_id := old.user_id;
  new.username := old.username;
  new.plan := old.plan;
  new.created_at := old.created_at;
  new.trial_ends_at := old.trial_ends_at;
  new.expires_at := old.expires_at;
  new.is_blocked := old.is_blocked;
  new.admin_note := old.admin_note;
  return new;
end;
$function$;

-- 8. Drop the legacy self-serve registration (phone-OTP era).
drop function if exists public.register_shop(text, text);

-- 9. RLS policies, re-keyed to the Firebase UID.
drop policy if exists "shop inserts own"                  on public.shops;
drop policy if exists "shop or admin updates"             on public.shops;
drop policy if exists "shop reads own or admin reads all" on public.shops;
drop policy if exists "admin deletes"                     on public.shops;
drop policy if exists "admin inserts"                     on public.shops;
drop policy if exists "insert own or admin"               on public.shops;
drop policy if exists "update own or admin"               on public.shops;

create policy "shop reads own or admin reads all"
  on public.shops for select
  using (user_id = public.fb_uid() or public.is_admin());

create policy "insert own or admin"
  on public.shops for insert
  with check (user_id = public.fb_uid() or public.is_admin());

create policy "update own or admin"
  on public.shops for update
  using (user_id = public.fb_uid() or public.is_admin())
  with check (user_id = public.fb_uid() or public.is_admin());

create policy "admin deletes"
  on public.shops for delete
  using (public.is_admin());

drop policy if exists "see admin rows" on public.admin_users;
create policy "see admin rows"
  on public.admin_users for select
  using (user_id = public.fb_uid() or public.is_admin());
