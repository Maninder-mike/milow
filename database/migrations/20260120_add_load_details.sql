-- =============================================================================
-- MIGRATION: Add load details fields to trips
-- Date: 2026-01-20
-- Purpose: Store load details for owner-operators (commodity, weight, pieces, refs)
-- =============================================================================

-- Add load detail columns to trips table
ALTER TABLE public.trips
ADD COLUMN IF NOT EXISTS commodity text,
ADD COLUMN IF NOT EXISTS weight numeric,
ADD COLUMN IF NOT EXISTS weight_unit text DEFAULT 'lbs',
ADD COLUMN IF NOT EXISTS pieces integer,
ADD COLUMN IF NOT EXISTS reference_numbers text[];

-- Add check constraint for weight unit
ALTER TABLE public.trips
ADD CONSTRAINT trips_weight_unit_check
CHECK (weight_unit IS NULL OR weight_unit IN ('lbs', 'kg'));

-- Comments for documentation
COMMENT ON COLUMN trips.commodity IS 'What is being hauled (e.g., Dry Goods, Reefer, Flatbed)';
COMMENT ON COLUMN trips.weight IS 'Load weight in specified unit';
COMMENT ON COLUMN trips.weight_unit IS 'Weight unit: lbs or kg';
COMMENT ON COLUMN trips.pieces IS 'Number of pallets/pieces';
COMMENT ON COLUMN trips.reference_numbers IS 'Array of customer reference numbers (PO#, Booking#, etc.)';
