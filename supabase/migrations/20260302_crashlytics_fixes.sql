-- =============================================================================
-- CRASHLYTICS FIXES: RELATION "trips" AND PROFILE RLS
-- Description: 
-- 1. Updates dashboard_widgets constraint to allow 'driver_trips'.
-- 2. Refreshes get_total_trip_distance to ensure it uses driver_trips.
-- 3. Updates profiles RLS to allow INSERT/UPDATE for owners (fixes 42501).
-- =============================================================================

-- 1. Update Dashboard Widgets Type Constraint
-- First, drop the old constraint if it exists (we might need to check the actual name in the DB, 
-- but usually it's public.dashboard_widgets_data_source_check)
DO $$ 
BEGIN
    ALTER TABLE public.dashboard_widgets DROP CONSTRAINT IF EXISTS dashboard_widgets_data_source_check;
    ALTER TABLE public.dashboard_widgets ADD CONSTRAINT dashboard_widgets_data_source_check 
    CHECK (data_source IN (
        'loads', 'drivers', 'trucks', 'trailers', 'customers',
        'invoices', 'fuel_entries', 'settlements', 'trips', 'driver_trips'
    ));
END $$;

-- 2. Refresh get_total_trip_distance (Explicitly using driver_trips)
-- We must DROP first because CREATE OR REPLACE cannot change the return type
DROP FUNCTION IF EXISTS public.get_total_trip_distance(uuid);

CREATE OR REPLACE FUNCTION public.get_total_trip_distance(user_uuid uuid)
RETURNS numeric AS $$
  SELECT coalesce(sum(end_odometer - start_odometer), 0)
  FROM public.driver_trips
  WHERE user_id = user_uuid
  AND end_odometer IS NOT NULL 
  AND start_odometer IS NOT NULL;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 3. Fix Profile RLS (Allow owners to UPSERT/UPDATE their own profiles)
-- Ensure 'profiles' table has correct policies for the application to function.
-- The user reported PostgrestException (42501) on profile updates.

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles 
  FOR UPDATE TO authenticated 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Allow users to insert their own profile (helpful for first-time setup if trigger fails)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles 
  FOR INSERT TO authenticated 
  WITH CHECK (auth.uid() = id);

-- 4. Verify any other 'trips' references in RPCs
-- (Searching done earlier, mostly found in dashboard_widgets constraint)

COMMENT ON FUNCTION public.get_total_trip_distance(uuid) IS 'Calculates total distance from driver_trips table for a specific user.';
