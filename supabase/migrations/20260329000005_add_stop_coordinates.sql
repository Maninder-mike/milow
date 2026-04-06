-- Migration: Add coordinates to stops table for geofencing
-- Created: 2026-03-29

ALTER TABLE stops ADD COLUMN IF NOT EXISTS latitude NUMERIC;
ALTER TABLE stops ADD COLUMN IF NOT EXISTS longitude NUMERIC;

-- Update RLS if needed (usually handled by table-level policies, but good to check)
-- Permissions are already inherited from the stops table policies.
