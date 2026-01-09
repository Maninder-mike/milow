-- Create driver_locations table
CREATE TABLE IF NOT EXISTS public.driver_locations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id uuid REFERENCES public.profiles(id) NOT NULL UNIQUE, -- One row per driver
    company_id uuid REFERENCES public.companies(id) NOT NULL, -- Cached for RLS perf
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    heading double precision,
    speed double precision,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_driver_locations_company_id ON public.driver_locations(company_id);
CREATE INDEX IF NOT EXISTS idx_driver_locations_driver_id ON public.driver_locations(driver_id);

-- Enable RLS
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

-- Policies

-- 1. Drivers can manage their OWN location
CREATE POLICY "Drivers can upsert their own location"
ON public.driver_locations
FOR ALL
USING (auth.uid() = driver_id)
WITH CHECK (auth.uid() = driver_id);

-- 2. Company members (Admins/Dispatchers) can VIEW locations for their company
CREATE POLICY "Company members can view driver locations"
ON public.driver_locations
FOR SELECT
USING (
    company_id IN (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
    )
);

-- 3. Service role has full access
CREATE POLICY "Service role full access"
ON public.driver_locations
FOR ALL
USING (auth.uid() IS NULL); -- Or equivalent check for service role
