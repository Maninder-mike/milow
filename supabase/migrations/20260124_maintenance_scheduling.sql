-- Maintenance Scheduling Feature for Milow Terminal
-- Run this migration in Supabase SQL Editor

-- ============================================================
-- 1. MAINTENANCE RECORDS TABLE (Service History)
-- ============================================================
CREATE TABLE IF NOT EXISTS maintenance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  service_type TEXT NOT NULL,
  description TEXT,
  odometer_at_service INTEGER,
  cost DECIMAL(10,2),
  performed_by TEXT,
  performed_at TIMESTAMP WITH TIME ZONE NOT NULL,
  next_due_odometer INTEGER,
  next_due_date DATE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id)
);

-- RLS Policies for maintenance_records
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view maintenance records for their org vehicles"
ON maintenance_records FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_records.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = auth.uid())
  )
);

CREATE POLICY "Users can create maintenance records for their org vehicles"
ON maintenance_records FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_records.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = auth.uid())
  )
);

CREATE POLICY "Users can update their own maintenance records"
ON maintenance_records FOR UPDATE
USING (created_by = auth.uid());

CREATE POLICY "Users can delete their own maintenance records"
ON maintenance_records FOR DELETE
USING (created_by = auth.uid());

-- ============================================================
-- 2. MAINTENANCE SCHEDULES TABLE (Proactive Alerts)
-- ============================================================
CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  service_type TEXT NOT NULL,
  interval_miles INTEGER,
  interval_days INTEGER,
  last_performed_at TIMESTAMP WITH TIME ZONE,
  last_odometer INTEGER,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vehicle_id, service_type)
);

-- RLS Policies for maintenance_schedules
ALTER TABLE maintenance_schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view maintenance schedules for their org vehicles"
ON maintenance_schedules FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_schedules.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = auth.uid())
  )
);

CREATE POLICY "Users can manage maintenance schedules for their org vehicles"
ON maintenance_schedules FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_schedules.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = auth.uid())
  )
);

-- ============================================================
-- 3. DVIR REPORTS TABLE (Driver Vehicle Inspection Reports)
-- ============================================================
CREATE TABLE IF NOT EXISTS dvir_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE NOT NULL,
  driver_id UUID REFERENCES profiles(id),
  inspection_type TEXT NOT NULL CHECK (inspection_type IN ('pre_trip', 'post_trip')),
  odometer INTEGER,
  defects_found BOOLEAN DEFAULT FALSE,
  defects JSONB DEFAULT '[]'::jsonb,
  is_safe_to_operate BOOLEAN NOT NULL,
  driver_signature TEXT,
  mechanic_signature TEXT,
  corrected_at TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Policies for dvir_reports
ALTER TABLE dvir_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view DVIR reports for their org vehicles"
ON dvir_reports FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = dvir_reports.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = auth.uid())
  )
);

CREATE POLICY "Users can create DVIR reports for their org vehicles"
ON dvir_reports FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = dvir_reports.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = auth.uid())
  )
);

CREATE POLICY "Users can update DVIR reports they created or for correction"
ON dvir_reports FOR UPDATE
USING (
  driver_id = auth.uid() OR 
  EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid() AND p.role IN ('admin', 'dispatcher', 'mechanic')
  )
);

-- ============================================================
-- 4. INDEXES FOR PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_maintenance_records_vehicle_id 
ON maintenance_records(vehicle_id);

CREATE INDEX IF NOT EXISTS idx_maintenance_records_performed_at 
ON maintenance_records(performed_at DESC);

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_vehicle_id 
ON maintenance_schedules(vehicle_id);

CREATE INDEX IF NOT EXISTS idx_dvir_reports_vehicle_id 
ON dvir_reports(vehicle_id);

CREATE INDEX IF NOT EXISTS idx_dvir_reports_created_at 
ON dvir_reports(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dvir_reports_uncorrected 
ON dvir_reports(vehicle_id) 
WHERE defects_found = TRUE AND is_safe_to_operate = FALSE AND corrected_at IS NULL;
