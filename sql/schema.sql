-- ARTFOS GOLD baseline schema for Supabase PostgreSQL.
-- Run in Supabase SQL Editor. Never expose service_role keys in the browser.
create extension if not exists pgcrypto;

create table if not exists public.member_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  username text not null unique,
  broker_name text not null default '',
  broker_account text not null default '',
  approval_status text not null default 'pending' check (approval_status in ('pending','approved','rejected','suspended')),
  membership text not null default 'gratis' check (membership in ('gratis','premium','vip')),
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create a least-privilege member profile from Auth metadata at signup.
-- Client-supplied metadata can never grant admin, approval, or a paid membership.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  requested_username text;
begin
  requested_username := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username', ''), '[^a-zA-Z0-9_.-]', '', 'g'));
  if length(requested_username) < 3 then
    requested_username := 'member_' || substr(replace(new.id::text, '-', ''), 1, 10);
  end if;
  if exists (select 1 from public.member_profiles where username = requested_username) then
    requested_username := left(requested_username, 35) || '_' || substr(replace(new.id::text, '-', ''), 1, 8);
  end if;
  insert into public.member_profiles(user_id, full_name, phone, username, broker_name, broker_account, approval_status, membership, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    requested_username,
    coalesce(new.raw_user_meta_data->>'broker_name', ''),
    coalesce(new.raw_user_meta_data->>'broker_account', ''),
    'pending', 'gratis', 'member'
  );
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_artfos on auth.users;
create trigger on_auth_user_created_artfos after insert on auth.users
for each row execute procedure public.handle_new_auth_user();

create table if not exists public.brokers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  referral_url text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.membership_plans (
  id text primary key check (id in ('gratis','premium','vip')),
  display_name text not null,
  price_label text not null default 'Hubungi admin',
  daily_signal_cap integer not null default 5 check (daily_signal_cap >= 0),
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);
insert into public.membership_plans(id,display_name,price_label,daily_signal_cap) values
 ('gratis','Gratis','Rp0',5),('premium','Premium','Sesuai pengaturan admin',15),('vip','VIP Access','Sesuai pengaturan admin',25)
on conflict (id) do nothing;

create table if not exists public.signals (
  id uuid primary key default gen_random_uuid(),
  instrument text not null,
  direction text not null check (direction in ('BUY','SELL')),
  entry_min numeric,
  entry_max numeric,
  stop_loss numeric,
  take_profit_1 numeric,
  take_profit_2 numeric,
  take_profit_3 numeric,
  analysis text not null default '',
  technical_context jsonb not null default '{}'::jsonb,
  news_context jsonb not null default '{}'::jsonb,
  risk_note text not null default 'Signal informasi; bukan jaminan hasil.',
  min_membership text not null default 'gratis' check (min_membership in ('gratis','premium','vip')),
  status text not null default 'active' check (status in ('active','pending','closed','cancelled','expired')),
  source text not null default 'admin' check (source in ('admin','tradingview','engine')),
  valid_until timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists signals_created_at_idx on public.signals(created_at desc);
create index if not exists signals_status_idx on public.signals(status);

create table if not exists public.signal_results (
  id uuid primary key default gen_random_uuid(),
  signal_id uuid not null references public.signals(id) on delete cascade,
  result_status text not null check (result_status in ('win','loss','breakeven','cancelled')),
  profit_usd numeric not null default 0,
  loss_usd numeric not null default 0,
  verified boolean not null default false,
  closed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create table if not exists public.news_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_name text not null,
  currency text not null default '',
  impact text not null default 'unknown' check (impact in ('low','medium','high','unknown')),
  actual_value text,
  forecast_value text,
  previous_value text,
  scheduled_at timestamptz,
  source_url text,
  created_at timestamptz not null default now()
);
create table if not exists public.site_settings (
  setting_key text primary key,
  setting_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists(select 1 from public.member_profiles p where p.user_id = auth.uid() and p.role = 'admin' and p.approval_status = 'approved') $$;
create or replace function public.has_signal_access(required_tier text)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.member_profiles p
    where p.user_id = auth.uid() and p.approval_status = 'approved'
      and case p.membership when 'vip' then 3 when 'premium' then 2 when 'gratis' then 1 else 0 end
      >= case required_tier when 'vip' then 3 when 'premium' then 2 else 1 end
  )
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.has_signal_access(text) from public;
grant execute on function public.has_signal_access(text) to authenticated;

alter table public.member_profiles enable row level security;
alter table public.brokers enable row level security;
alter table public.membership_plans enable row level security;
alter table public.signals enable row level security;
alter table public.signal_results enable row level security;
alter table public.news_events enable row level security;
alter table public.site_settings enable row level security;

drop policy if exists "profile read self or admin" on public.member_profiles;
create policy "profile read self or admin" on public.member_profiles for select to authenticated using (user_id = auth.uid() or public.is_admin());
drop policy if exists "profile insert self pending member" on public.member_profiles;
create policy "profile insert self pending member" on public.member_profiles for insert to authenticated with check (user_id = auth.uid() and role = 'member' and approval_status = 'pending' and membership = 'gratis');
drop policy if exists "profile update admin only" on public.member_profiles;
create policy "profile update admin only" on public.member_profiles for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "active brokers public read" on public.brokers;
create policy "active brokers public read" on public.brokers for select to anon, authenticated using (is_active = true or public.is_admin());
drop policy if exists "broker admin all" on public.brokers;
create policy "broker admin all" on public.brokers for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "active plans public read" on public.membership_plans;
create policy "active plans public read" on public.membership_plans for select to anon, authenticated using (is_active = true or public.is_admin());
drop policy if exists "plans admin all" on public.membership_plans;
create policy "plans admin all" on public.membership_plans for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "signals member entitlement read" on public.signals;
create policy "signals member entitlement read" on public.signals for select to authenticated using (status = 'active' and public.has_signal_access(min_membership));
drop policy if exists "signals admin all" on public.signals;
create policy "signals admin all" on public.signals for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "verified results with signal access" on public.signal_results;
create policy "verified results with signal access" on public.signal_results for select to authenticated using (verified = true and exists (select 1 from public.signals s where s.id = signal_id and public.has_signal_access(s.min_membership)));
drop policy if exists "results admin all" on public.signal_results;
create policy "results admin all" on public.signal_results for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "news read signed in" on public.news_events;
create policy "news read signed in" on public.news_events for select to authenticated using (true);
drop policy if exists "news admin all" on public.news_events;
create policy "news admin all" on public.news_events for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "settings admin only" on public.site_settings;
create policy "settings admin only" on public.site_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- IMPORTANT ADMIN BOOTSTRAP:
-- 1) Register the intended admin through Supabase Auth.
-- 2) Copy that user's UUID from Authentication > Users.
-- 3) Run the statement below after replacing UUID_HERE. Do not use a public/admin password in source code.
-- update public.member_profiles set role='admin', approval_status='approved' where user_id='UUID_HERE';
