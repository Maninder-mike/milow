-- =============================================================================
-- MIGRATION: 20260109_fix_profile_creation.sql
-- Purpose: Allow authenticated users to INSERT their own profile rows.
--          This serves as a fallback/robustness mechanism if the database trigger fail.
-- =============================================================================

-- 1. Policies for public.profiles
-- Allow users to insert their own row in the base profiles table.
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile" on public.profiles
    for insert to authenticated with check (auth.uid() = id);

-- 2. Policies for public.driver_profiles
-- Allow users to insert their own row in the driver_profiles table.
drop policy if exists "Drivers can insert own profile" on public.driver_profiles;
create policy "Drivers can insert own profile" on public.driver_profiles
    for insert to authenticated with check (auth.uid() = id);

-- 3. Policies for public.company_staff_profiles
-- Allow staff to insert their own row (if applicable).
drop policy if exists "Staff can insert own profile" on public.company_staff_profiles;
create policy "Staff can insert own profile" on public.company_staff_profiles
    for insert to authenticated with check (auth.uid() = id);
