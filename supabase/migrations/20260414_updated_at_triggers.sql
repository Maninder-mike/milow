-- Migration Name: 20260414_updated_at_triggers.sql
-- Description: Adds updated_at triggers to driver_trips and fuel_entries tables
-- to ensure Supabase always sets the latest timestamp on server updates.
-- This provides a rigid last-write-wins (LWW) conflict resolution for offline sync.

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for driver_trips
DROP TRIGGER IF EXISTS set_driver_trips_updated_at ON public.driver_trips;
CREATE TRIGGER set_driver_trips_updated_at
  BEFORE UPDATE ON public.driver_trips
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();

-- Trigger for fuel_entries
DROP TRIGGER IF EXISTS set_fuel_entries_updated_at ON public.fuel_entries;
CREATE TRIGGER set_fuel_entries_updated_at
  BEFORE UPDATE ON public.fuel_entries
  FOR EACH ROW EXECUTE PROCEDURE public.set_updated_at();
