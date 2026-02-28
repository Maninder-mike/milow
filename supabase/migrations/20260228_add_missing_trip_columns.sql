-- Migration: Add missing columns to driver_trips and fuel_entries tables
-- These columns exist in the application models but were never added to the 
-- Supabase schema, causing insert failures.

-- =============================================
-- 1. DRIVER_TRIPS TABLE - Add missing columns
-- =============================================

ALTER TABLE public.driver_trips
  ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES public.vehicles(id),
  ADD COLUMN IF NOT EXISTS pickup_times jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS delivery_times jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS pickup_completed jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS delivery_completed jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS pickup_detention jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS delivery_detention jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS is_empty_leg boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS commodity text,
  ADD COLUMN IF NOT EXISTS weight numeric,
  ADD COLUMN IF NOT EXISTS weight_unit text DEFAULT 'lbs',
  ADD COLUMN IF NOT EXISTS pieces integer,
  ADD COLUMN IF NOT EXISTS reference_numbers text[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Index for vehicle lookups
CREATE INDEX IF NOT EXISTS driver_trips_vehicle_id_idx ON public.driver_trips(vehicle_id);

-- =============================================
-- 2. FUEL_ENTRIES TABLE - Add missing column
-- =============================================

ALTER TABLE public.fuel_entries
  ADD COLUMN IF NOT EXISTS vehicle_id uuid REFERENCES public.vehicles(id);

-- Index for vehicle lookups  
CREATE INDEX IF NOT EXISTS fuel_entries_vehicle_id_idx ON public.fuel_entries(vehicle_id);
