-- SQL Migration: Add driver feature columns and new tables for Quick Notes and Incidents

-- 1. Add revenue and rate_per_mile columns to driver_trips
ALTER TABLE public.driver_trips 
ADD COLUMN IF NOT EXISTS revenue NUMERIC,
ADD COLUMN IF NOT EXISTS rate_per_mile NUMERIC;

-- 2. Create QUICK NOTES table
CREATE TABLE IF NOT EXISTS public.quick_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    trip_id UUID REFERENCES public.driver_trips(id) ON DELETE SET NULL,
    title TEXT,
    content TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for quick_notes
ALTER TABLE public.quick_notes ENABLE ROW LEVEL SECURITY;

-- Policies for quick_notes
DROP POLICY IF EXISTS "Users can view own quick notes" ON public.quick_notes;
CREATE POLICY "Users can view own quick notes"
ON public.quick_notes FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own quick notes" ON public.quick_notes;
CREATE POLICY "Users can insert own quick notes"
ON public.quick_notes FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own quick notes" ON public.quick_notes;
CREATE POLICY "Users can update own quick notes"
ON public.quick_notes FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own quick notes" ON public.quick_notes;
CREATE POLICY "Users can delete own quick notes"
ON public.quick_notes FOR DELETE
USING (auth.uid() = user_id);


-- 3. Create INCIDENTS table
CREATE TABLE IF NOT EXISTS public.incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    company_id UUID REFERENCES public.companies(id) ON DELETE SET NULL,
    trip_id UUID REFERENCES public.driver_trips(id) ON DELETE SET NULL,
    incident_date TIMESTAMPTZ NOT NULL,
    location TEXT,
    description TEXT NOT NULL,
    police_report_number TEXT,
    police_department TEXT,
    third_party_info JSONB DEFAULT '{}'::jsonb,
    photos JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for incidents
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

-- Policies for incidents
DROP POLICY IF EXISTS "Users can view own or company incidents" ON public.incidents;
CREATE POLICY "Users can view own or company incidents"
ON public.incidents FOR SELECT
USING (
    auth.uid() = user_id OR 
    (company_id IS NOT NULL AND company_id IN (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
    ))
);

DROP POLICY IF EXISTS "Users can insert own incidents" ON public.incidents;
CREATE POLICY "Users can insert own incidents"
ON public.incidents FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own incidents" ON public.incidents;
CREATE POLICY "Users can update own incidents"
ON public.incidents FOR UPDATE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own incidents" ON public.incidents;
CREATE POLICY "Users can delete own incidents"
ON public.incidents FOR DELETE
USING (auth.uid() = user_id);

-- Trigger for auto-setting company_id on incidents
DROP TRIGGER IF EXISTS set_incident_company_id_trigger ON public.incidents;
CREATE TRIGGER set_incident_company_id_trigger
  BEFORE INSERT ON public.incidents
  FOR EACH ROW EXECUTE PROCEDURE public.set_company_id();

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_quick_notes_user_id ON public.quick_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_quick_notes_trip_id ON public.quick_notes(trip_id);
CREATE INDEX IF NOT EXISTS idx_incidents_user_id ON public.incidents(user_id);
CREATE INDEX IF NOT EXISTS idx_incidents_company_id ON public.incidents(company_id);
CREATE INDEX IF NOT EXISTS idx_incidents_trip_id ON public.incidents(trip_id);
