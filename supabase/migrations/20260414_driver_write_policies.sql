-- Migration Name: 20260414_driver_write_policies.sql
-- Description: Adds missing INSERT, UPDATE, and DELETE RLS policies for driver_trips and fuel_entries.
-- This ensures offline writes sync properly instead of silently failing due to RLS restrictions.

-- driver_trips: INSERT
CREATE POLICY "Drivers can insert own trips" ON public.driver_trips
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- driver_trips: UPDATE
CREATE POLICY "Drivers can update own trips" ON public.driver_trips
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- driver_trips: DELETE
CREATE POLICY "Drivers can delete own trips" ON public.driver_trips
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);

-- fuel_entries: INSERT
CREATE POLICY "Drivers can insert own fuel entries" ON public.fuel_entries
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- fuel_entries: UPDATE
CREATE POLICY "Drivers can update own fuel entries" ON public.fuel_entries
  FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- fuel_entries: DELETE
CREATE POLICY "Drivers can delete own fuel entries" ON public.fuel_entries
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
