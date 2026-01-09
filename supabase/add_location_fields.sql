-- Add location fields to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS current_latitude double precision,
ADD COLUMN IF NOT EXISTS current_longitude double precision,
ADD COLUMN IF NOT EXISTS last_location_updated_at timestamptz;

-- Ideally, we might want an index if we query by location often, but for now filtering by company_id is enough.
