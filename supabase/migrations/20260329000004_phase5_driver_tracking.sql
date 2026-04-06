-- Migration: 20260329000004_phase5_driver_tracking.sql
-- Purpose: Enable real-time for driver locations and add metadata to profiles

-- 1. Enable Real-time for driver_locations
-- Note: Requires superuser or specific extension setup in Supabase dashboard,
-- but this SQL provides the intent for the replication slot.
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_locations;

-- 2. Add last location metadata to profiles for quick fleet-wide lookups
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS last_location_updated_at timestamptz,
ADD COLUMN IF NOT EXISTS last_latitude double precision,
ADD COLUMN IF NOT EXISTS last_longitude double precision;

-- 3. Create a function to auto-update profile location when driver_locations changes
CREATE OR REPLACE FUNCTION public.sync_profile_location_on_update()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.profiles
  SET 
    last_latitude = NEW.latitude,
    last_longitude = NEW.longitude,
    last_location_updated_at = NEW.updated_at
  WHERE id = NEW.driver_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create trigger
DROP TRIGGER IF EXISTS on_driver_location_update ON public.driver_locations;
CREATE TRIGGER on_driver_location_update
  AFTER INSERT OR UPDATE ON public.driver_locations
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_profile_location_on_update();

-- 5. RLS: Ensure Company members can see the new profile columns
-- (Usually profiles are already viewable by company members, but let's be explicit if needed)

COMMENT ON COLUMN public.profiles.last_latitude IS 'Last known latitude from automated tracking';
COMMENT ON COLUMN public.profiles.last_longitude IS 'Last known longitude from automated tracking';
COMMENT ON COLUMN public.profiles.last_location_updated_at IS 'Timestamp of the last location update';
