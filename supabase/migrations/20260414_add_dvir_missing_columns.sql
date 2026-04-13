-- Migration: Add missing columns to dvir_reports for model parity and performance
-- Path: supabase/migrations/20260414_add_dvir_missing_columns.sql

-- 1. Add missing columns
ALTER TABLE dvir_reports 
ADD COLUMN IF NOT EXISTS location TEXT,
ADD COLUMN IF NOT EXISTS trailer_id TEXT,
ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id);

-- 2. Populate company_id for existing records (joining with vehicles)
UPDATE dvir_reports
SET company_id = v.company_id
FROM vehicles v
WHERE dvir_reports.vehicle_id = v.id
AND dvir_reports.company_id IS NULL;

-- 3. Update RLS policies to use company_id from JWT claims (Performance Optimization)
-- This aligns with the 20260408 patterns

DROP POLICY IF EXISTS "Users can view DVIR reports for their org vehicles" ON dvir_reports;
CREATE POLICY "Users can view DVIR reports for their org vehicles"
ON dvir_reports FOR SELECT
TO authenticated
USING (
  company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid
);

DROP POLICY IF EXISTS "Users can create DVIR reports for their org vehicles" ON dvir_reports;
CREATE POLICY "Users can create DVIR reports for their org vehicles"
ON dvir_reports FOR INSERT
TO authenticated
WITH CHECK (
  company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid
);

-- Index for the new company_id column
CREATE INDEX IF NOT EXISTS idx_dvir_reports_company_id ON dvir_reports(company_id);
