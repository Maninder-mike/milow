-- Add is_empty_leg column to trips table
ALTER TABLE public.trips 
ADD COLUMN IF NOT EXISTS is_empty_leg boolean DEFAULT false;

COMMENT ON COLUMN public.trips.is_empty_leg IS 'Flag indicating if the trip is an empty leg (no cargo)';
