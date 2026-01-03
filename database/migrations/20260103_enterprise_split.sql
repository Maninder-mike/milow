-- =============================================================================
-- MIGRATION: 20260103_enterprise_split.sql
-- Purpose: Split 'profiles' into 'driver_profiles' and 'company_staff_profiles'
--          Keep 'profiles' as a lightweight registry.
-- =============================================================================

-- 1. Create Driver Profiles Table
create table if not exists public.driver_profiles (
    id uuid references public.profiles(id) on delete cascade not null primary key,
    
    -- Personal Info (Moved from profiles)
    full_name text,
    avatar_url text,
    
    -- Address (Specific to Driver)
    address text,
    city text,
    state_province text,
    postal_code text,
    country text,
    
    -- Driver Specific Compliance
    date_of_birth date,
    license_number text,
    license_type text,
    citizenship text,
    fast_id text,
    
    -- Company Relation (Foreign Key)
    company_id uuid references public.companies(id),
    
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- 2. Create Company Staff Profiles Table (Admins, Dispatchers, Safety Officers)
create table if not exists public.company_staff_profiles (
    id uuid references public.profiles(id) on delete cascade not null primary key,
    
    -- Personal Info
    full_name text,
    avatar_url text,
    
    -- Address (Personal address of staff)
    address text,
    city text,
    state_province text,
    postal_code text,
    country text,
    
    -- Staff Specifics
    position text, -- E.g. 'Safety Manager'
    
    -- Company Relation
    company_id uuid references public.companies(id),
    
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- 3. Enable RLS on New Tables
alter table public.driver_profiles enable row level security;
alter table public.company_staff_profiles enable row level security;

-- 4. Create RLS Policies

-- RLS: Driver Profiles
-- Drivers can view/edit their own profile
drop policy if exists "Drivers can view own profile" on public.driver_profiles;
create policy "Drivers can view own profile" on public.driver_profiles
    for select to authenticated using (auth.uid() = id);

drop policy if exists "Drivers can update own profile" on public.driver_profiles;
create policy "Drivers can update own profile" on public.driver_profiles
    for update to authenticated using (auth.uid() = id);

-- Company Admins/Dispatchers can view drivers in their company
drop policy if exists "Company staff can view their drivers" on public.driver_profiles;
create policy "Company staff can view their drivers" on public.driver_profiles
    for select to authenticated using (
        exists (
            select 1 from public.company_staff_profiles staff
            where staff.id = auth.uid()
            and staff.company_id = driver_profiles.company_id
        )
         -- Fallback for migration (if admin hasn't migrated yet check base profile)
        or exists (
            select 1 from public.profiles
            where id = auth.uid() 
            and role in ('admin', 'dispatcher', 'safetyOfficer')
            and company_id = driver_profiles.company_id
        )
    );

-- RLS: Company Staff Profiles
-- Staff can view/edit their own profile
drop policy if exists "Staff can view own profile" on public.company_staff_profiles;
create policy "Staff can view own profile" on public.company_staff_profiles
    for select to authenticated using (auth.uid() = id);

drop policy if exists "Staff can update own profile" on public.company_staff_profiles;
create policy "Staff can update own profile" on public.company_staff_profiles
    for update to authenticated using (auth.uid() = id);

-- Admins can view other staff in their company
drop policy if exists "Admins can view company staff" on public.company_staff_profiles;
create policy "Admins can view company staff" on public.company_staff_profiles
    for select to authenticated using (
        exists (
            select 1 from public.profiles
            where id = auth.uid() 
            and role = 'admin'
            and company_id = company_staff_profiles.company_id
        )
    );


-- 5. Data Migration (Backfill)

-- Migrate Drivers
insert into public.driver_profiles (
    id, full_name, avatar_url, 
    address, city, state_province, postal_code, country,
    date_of_birth, license_number, license_type, citizenship, fast_id,
    company_id
)
select 
    id, full_name, avatar_url,
    address, city, state_province, postal_code, country,
    date_of_birth, license_number, license_type, citizenship, fast_id,
    company_id
from public.profiles
where role = 'driver'
on conflict (id) do nothing;

-- Migrate Staff (Admins, Dispatchers, etc)
insert into public.company_staff_profiles (
    id, full_name, avatar_url,
    address, city, state_province, postal_code, country,
    company_id
)
select 
    id, full_name, avatar_url,
    address, city, state_province, postal_code, country,
    company_id
from public.profiles
where role in ('admin', 'dispatcher', 'safetyOfficer', 'assistant')
on conflict (id) do nothing;


-- 6. Trigger Update (Auto-sort new users)
create or replace function public.handle_new_user() 
returns trigger as $$
declare
  v_role text;
  v_full_name text;
  v_avatar_url text;
  v_company_id uuid; -- If you passed company_id in metadata
begin
  -- 1. Extract Metadata
  v_role := coalesce(new.raw_user_meta_data->>'role', 'pending');
  v_full_name := new.raw_user_meta_data->>'full_name';
  v_avatar_url := coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture');
  
  -- 2. Insert into Base Registry (profiles)
  insert into public.profiles (id, email, full_name, avatar_url, role, is_verified, created_at)
  values (
    new.id, 
    new.email, 
    v_full_name, -- Keep Searchable Display Name
    v_avatar_url, -- Keep Thumbnail
    v_role,
    (v_role = 'admin'), 
    now()
  );

  -- 3. Sort into Specific Table
  if v_role = 'driver' then
    insert into public.driver_profiles (id, full_name, avatar_url)
    values (new.id, v_full_name, v_avatar_url);
    
  elsif v_role in ('admin', 'dispatcher', 'safetyOfficer', 'assistant') then
    insert into public.company_staff_profiles (id, full_name, avatar_url)
    values (new.id, v_full_name, v_avatar_url);
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- Re-attach trigger if needed (logic stays same, function body updated)

-- 7. CLEANUP (OPTIONAL - Run manually later or uncomment when ready)
-- We remove the duplicated columns from the base 'profiles' table to enforce usage of new tables.
-- NOT removing 'company_id' from base yet as it is heavily used by RLS in other tables.
/*
alter table public.profiles 
  drop column full_name,
  drop column avatar_url,
  drop column address,
  drop column city,
  drop column state_province,
  drop column postal_code,
  drop column country,
  drop column date_of_birth,
  drop column license_number,
  drop column license_type,
  drop column citizenship,
  drop column fast_id;
*/
