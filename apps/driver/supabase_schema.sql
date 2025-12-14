-- ============================================
-- 1. PROFILES & AUTH MANAGEMENT
-- ============================================

-- Create a table for public profiles link to auth.users
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

-- RLS for profiles
alter table profiles enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- Trigger to handle new user creation automatically
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

-- ============================================
-- 2. STORAGE BUCKETS (AVATARS)
-- ============================================

-- Create a public storage bucket for avatars
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- RLS for storage
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
-- 3. TRIPS TABLE
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
  border_crossing text,                      -- Added via migration: Optional border crossing location
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

comment on column trips.border_crossing is 'Optional border crossing location (e.g., Windsor-Detroit, Laredo)';

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

-- Indexes for trips
create index trips_user_id_idx on trips(user_id);
create index trips_trip_date_idx on trips(trip_date desc);

-- ============================================
-- 4. FUEL ENTRIES TABLE
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
  
  -- DEF Columns (Added via migration)
  def_quantity numeric default 0,
  def_price numeric default 0,
  def_from_yard boolean default false,

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

-- Indexes for fuel entries
create index fuel_entries_user_id_idx on fuel_entries(user_id);
create index fuel_entries_fuel_date_idx on fuel_entries(fuel_date desc);

-- ============================================
-- 5. APP VERSION MANAGEMENT
-- ============================================

create table if not exists app_version (
  id bigint generated always as identity primary key,
  platform text not null,              -- 'android' or 'ios'
  latest_version text not null,        -- e.g., 'v1.0.5' or '1.0.5'
  download_url text not null,          -- GitHub release asset URL or app store link
  changelog text,                       -- Optional release notes/changelog
  min_supported_version text,          -- Minimum version that can still run (for force updates)
  is_critical boolean default false,   -- If true, force user to update
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Ensure only one row per platform
create unique index if not exists app_version_platform_idx 
  on app_version (platform);

-- Enable RLS for app_version
alter table app_version enable row level security;

-- Allow public read access (so app can check for updates)
create policy "Allow public read access" 
  on app_version for select 
  using (true);

-- Insert initial row for Android (upsert)
insert into app_version (platform, latest_version, download_url, changelog, min_supported_version, is_critical)
values (
  'android', 
  'v0.0.1', 
  'https://github.com/maninder-mike/milow/releases/latest',
  'Initial release',
  'v0.0.1',
  false
)
on conflict (platform) do nothing;

-- Function to automatically update the updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger to update updated_at on row update
drop trigger if exists update_app_version_updated_at on app_version;
create trigger update_app_version_updated_at
  before update on app_version
  for each row
  execute function update_updated_at_column();
