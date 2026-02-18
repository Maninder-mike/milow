-- =============================================================================
-- MIGRATION: 20260217_fix_profile_updates.sql
-- Purpose: Allow authenticated users to UPDATE their own profile rows.
--          The previous migration (20260109) only added INSERT policies,
--          which caused upserts to fail when the row already existed.
-- =============================================================================

-- 1. Policies for public.profiles
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
    for update to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- 2. Policies for public.driver_profiles
drop policy if exists "Drivers can update own profile" on public.driver_profiles;
create policy "Drivers can update own profile" on public.driver_profiles
    for update to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);
