-- Migration: 20260228_driver_status.sql
-- Purpose: Track driver availability status for dispatchers

-- 1. Add driver_status column to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS driver_status text DEFAULT 'off_duty'
CHECK (driver_status IN ('available', 'on_duty', 'driving', 'off_duty', 'sleeper')),
ADD COLUMN IF NOT EXISTS driver_status_updated_at timestamptz DEFAULT now();

-- 2. Create index for performance
CREATE INDEX IF NOT EXISTS idx_profiles_driver_status ON public.profiles(driver_status);

-- 3. Create trigger to update driver_status_updated_at
CREATE OR REPLACE FUNCTION public.handle_driver_status_update()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.driver_status IS DISTINCT FROM NEW.driver_status THEN
    NEW.driver_status_updated_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_driver_status_change ON public.profiles;
CREATE TRIGGER on_driver_status_change
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_driver_status_update();

-- 4. Comments
COMMENT ON COLUMN public.profiles.driver_status IS 'Availability status of the driver (available, on_duty, driving, off_duty, sleeper)';
COMMENT ON COLUMN public.profiles.driver_status_updated_at IS 'Timestamp of the last status change';
