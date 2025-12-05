-- Create a table for public profiles
create table profiles (
  id uuid references auth.users not null primary key,
  updated_at timestamp with time zone,
  full_name text,
  avatar_url text,
  website text,
  address text,
  country text,
  phone text,
  email text,
  company_name text,
  company_code text
);

-- Set up Row Level Security (RLS)
-- See https://supabase.com/docs/guides/auth/row-level-security for more details.
alter table profiles enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- This triggers a reaction whenever a new user is created
-- Create or replace to avoid duplicate definition errors
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Recreate trigger idempotently
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Create a public storage bucket for avatars (run once)
-- Note: If bucket already exists, this section can be skipped.
-- select * from storage.buckets where name = 'avatars';
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Allow public read on the avatars bucket and owner write
create policy "Public read for avatars"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Users can upload their avatars"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update their avatars"
  on storage.objects for update
  using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their avatars"
  on storage.objects for delete
  using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================
-- TRIPS TABLE
-- ============================================
create table trips (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  trip_number text not null,
  truck_number text not null,
  trailers text[] default '{}',
  trip_date timestamptz not null,
  pickup_locations text[] not null,
  delivery_locations text[] not null,
  start_odometer numeric,
  end_odometer numeric,
  distance_unit text not null default 'mi',  -- 'mi' or 'km'
  border_crossing text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Trips RLS
alter table trips enable row level security;

create policy "Users can view own trips" on trips
  for select using (auth.uid() = user_id);

create policy "Users can insert own trips" on trips
  for insert with check (auth.uid() = user_id);

create policy "Users can update own trips" on trips
  for update using (auth.uid() = user_id);

create policy "Users can delete own trips" on trips
  for delete using (auth.uid() = user_id);

-- Index for faster queries
create index trips_user_id_idx on trips(user_id);
create index trips_trip_date_idx on trips(trip_date desc);

-- ============================================
-- FUEL ENTRIES TABLE
-- ============================================
create table fuel_entries (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  fuel_date timestamptz not null,
  fuel_type text not null check (fuel_type in ('truck', 'reefer')),
  truck_number text,
  reefer_number text,
  location text,
  odometer_reading numeric,
  reefer_hours numeric,
  fuel_quantity numeric not null,
  price_per_unit numeric not null,
  fuel_unit text not null default 'gal',     -- 'gal' or 'L'
  distance_unit text not null default 'mi',  -- 'mi' or 'km'
  currency text not null default 'USD',      -- 'USD' or 'CAD'
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Fuel entries RLS
alter table fuel_entries enable row level security;

create policy "Users can view own fuel entries" on fuel_entries
  for select using (auth.uid() = user_id);

create policy "Users can insert own fuel entries" on fuel_entries
  for insert with check (auth.uid() = user_id);

create policy "Users can update own fuel entries" on fuel_entries
  for update using (auth.uid() = user_id);

create policy "Users can delete own fuel entries" on fuel_entries
  for delete using (auth.uid() = user_id);

-- Index for faster queries
create index fuel_entries_user_id_idx on fuel_entries(user_id);
create index fuel_entries_fuel_date_idx on fuel_entries(fuel_date desc);
