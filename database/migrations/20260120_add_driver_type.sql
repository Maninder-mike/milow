-- =============================================================================
-- MIGRATION: Add driver_type to profiles
-- Date: 2026-01-20
-- Purpose: Store driver type for feature gating (company driver vs owner-operator)
-- =============================================================================

-- Add driver_type column to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS driver_type text DEFAULT 'companyDriver';

-- Add check constraint for valid values
ALTER TABLE public.profiles
ADD CONSTRAINT profiles_driver_type_check
CHECK (driver_type IN ('companyDriver', 'ownerOperator', 'leaseOperator'));

-- Comment for documentation
COMMENT ON COLUMN profiles.driver_type IS 'Driver classification: companyDriver, ownerOperator, or leaseOperator. Used for feature gating.';

-- Create index for potential filtering
CREATE INDEX IF NOT EXISTS idx_profiles_driver_type ON public.profiles(driver_type);
