-- Migration: Add border_crossing column to trips table
-- Date: 2025-12-05
-- Description: Adds an optional border_crossing text field to store the border crossing used for a trip

-- Add the border_crossing column to the trips table
ALTER TABLE trips ADD COLUMN IF NOT EXISTS border_crossing text;

-- Add a comment to document the column
COMMENT ON COLUMN trips.border_crossing IS 'Optional border crossing location (e.g., Windsor-Detroit, Laredo)';
