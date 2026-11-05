-- AgriWaste Connect production schema
-- Run this entire file in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'farmer' check (role in ('farmer','buyer','entrepreneur','student','admin')),
  district text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id,display_name,role)
  values(new.id, coalesce(new.raw_user_meta_data->>'display_name','New user'),
    case when new.raw_user_meta_data->>'role' in ('farmer','buyer','entrepreneur','student') then new.raw_user_meta_data->>'role' else 'farmer' end)
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.waste_listings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  material text not null,
  category text not null,
  quantity_kg numeric(14,2) not null check(quantity_kg > 0),
  price_per_kg numeric(12,2) not null check(price_per_kg >= 0),
  location_text text not null,
  quality text not null default 'Not specified',
  details text,
  -- Coordinates are optional and are only stored when the supplier explicitly chooses to attach them.
  latitude double precision check(latitude between -90 and 90),
  longitude double precision check(longitude between -180 and 180),
  status text not null default 'published' check(status in ('pending','published','rejected','sold','archived')),
  created_at timestamptz not null default now()
);
create index if not exists waste_listings_search_idx on public.waste_listings(status,category,created_at desc);
create index if not exists waste_listings_user_idx on public.waste_listings(user_id);

create table if not exists public.price_quotes (
  id uuid primary key default gen_random_uuid(),
  submitted_by uuid references auth.users(id) on delete set null,
  material text not null,
  price_per_kg numeric(12,2) not null check(price_per_kg >= 0),
  location_text text not null,
  source_label text not null,
  observed_at date not null default current_date,
  status text not null default 'pending' check(status in ('pending','published','verified','rejected')),
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists price_quotes_lookup_idx on public.price_quotes(status,material,observed_at desc);

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.waste_listings(id) on delete cascade,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  requested_quantity_kg numeric(14,2) not null check(requested_quantity_kg > 0),
  message text not null,
  status text not null default 'open' check(status in ('open','responded','accepted','closed')),
  created_at timestamptz not null default now()
);
create index if not exists enquiries_listing_idx on public.enquiries(listing_id,created_at desc);

alter table public.profiles enable row level security;
alter table public.waste_listings enable row level security;
alter table public.price_quotes enable row level security;
alter table public.enquiries enable row level security;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;

drop policy if exists "profiles select authenticated" on public.profiles;
create policy "profiles select authenticated" on public.profiles for select to authenticated using (true);
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated using (id=auth.uid()) with check (id=auth.uid() and role <> 'admin' or public.is_admin());

drop policy if exists "published listings readable" on public.waste_listings;
create policy "published listings readable" on public.waste_listings for select to anon,authenticated using (status='published' or user_id=auth.uid() or public.is_admin());
drop policy if exists "users insert own listings" on public.waste_listings;
create policy "users insert own listings" on public.waste_listings for insert to authenticated with check (user_id=auth.uid() and status='published');
drop policy if exists "users update own listings" on public.waste_listings;
create policy "users update own listings" on public.waste_listings for update to authenticated using (user_id=auth.uid() or public.is_admin()) with check (user_id=auth.uid() or public.is_admin());
drop policy if exists "users delete own listings" on public.waste_listings;
create policy "users delete own listings" on public.waste_listings for delete to authenticated using (user_id=auth.uid() or public.is_admin());

drop policy if exists "published quotes readable" on public.price_quotes;
create policy "published quotes readable" on public.price_quotes for select to anon,authenticated using (status in ('published','verified') or submitted_by=auth.uid() or public.is_admin());
drop policy if exists "users submit quotes pending" on public.price_quotes;
create policy "users submit quotes pending" on public.price_quotes for insert to authenticated with check (submitted_by=auth.uid() and status='pending');
drop policy if exists "admins manage quotes" on public.price_quotes;
create policy "admins manage quotes" on public.price_quotes for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "buyers create enquiries" on public.enquiries;
create policy "buyers create enquiries" on public.enquiries for insert to authenticated with check (buyer_id=auth.uid());
drop policy if exists "parties read enquiries" on public.enquiries;
create policy "parties read enquiries" on public.enquiries for select to authenticated using (buyer_id=auth.uid() or exists(select 1 from public.waste_listings l where l.id=listing_id and l.user_id=auth.uid()) or public.is_admin());
drop policy if exists "parties update enquiries" on public.enquiries;
create policy "parties update enquiries" on public.enquiries for update to authenticated using (buyer_id=auth.uid() or exists(select 1 from public.waste_listings l where l.id=listing_id and l.user_id=auth.uid()) or public.is_admin()) with check (buyer_id=auth.uid() or exists(select 1 from public.waste_listings l where l.id=listing_id and l.user_id=auth.uid()) or public.is_admin());

grant usage on schema public to anon,authenticated;
grant select on public.waste_listings,public.price_quotes to anon,authenticated;
grant insert,update,delete on public.waste_listings to authenticated;
grant insert,select,update on public.price_quotes to authenticated;
grant select,insert,update on public.enquiries to authenticated;
grant select,update on public.profiles to authenticated;
