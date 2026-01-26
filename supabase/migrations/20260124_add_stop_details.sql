-- Migration: Add detailed freight columns to stops table
-- Created: 2026-01-24

ALTER TABLE stops ADD COLUMN IF NOT EXISTS commodity TEXT;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS quantity TEXT;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS weight NUMERIC;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS weight_unit TEXT;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS stop_reference TEXT;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS instructions TEXT;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS appointment_time TIMESTAMPTZ;
