-- =============================================================================
-- PERFORMANCE TUNING: INDEXES AND RLS OPTIMIZATION
-- Description: 
-- 1. Adds missing indexes for high-frequency filtering and sorting.
-- 2. Optimizes RLS helper functions.
-- 3. Refactors inefficient RLS subqueries to use EXISTS.
-- =============================================================================

-- 1. HIGH-PRIORITY INDEXES

-- driver_trips: Support dashboard and history filtering
CREATE INDEX IF NOT EXISTS idx_driver_trips_user_time 
ON public.driver_trips(user_id, trip_date DESC);

CREATE INDEX IF NOT EXISTS idx_driver_trips_company 
ON public.driver_trips(company_id);

-- notifications: Support fast inbox loading
CREATE INDEX IF NOT EXISTS idx_notifications_user_time 
ON public.notifications(user_id, created_at DESC);

-- loads: Support main dispatcher list
CREATE INDEX IF NOT EXISTS idx_loads_created_at_desc 
ON public.loads(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_loads_company_status 
ON public.loads(company_id, status);

-- stops: Support load detail view
CREATE INDEX IF NOT EXISTS idx_stops_load_sequence 
ON public.stops(load_id, sequence_id);

-- 2. RLS HELPER OPTIMIZATION

-- Ensure get_my_company_id is STABLE to avoid row-by-row re-evaluation if it wasn't already.
-- (We use DO block to be safe if the function exists with different signature)
CREATE OR REPLACE FUNCTION public.get_my_company_id()
RETURNS uuid AS $$
  SELECT company_id 
  FROM public.profiles 
  WHERE id = (select auth.uid());
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 3. RLS SUBQUERY REFACTORING

-- Refactor messages policy for better performance on large loads table
DROP POLICY IF EXISTS "Strict message read access" ON public.messages;
DROP POLICY IF EXISTS "Users can view relevant messages" ON public.messages;
CREATE POLICY "Strict message read access"
ON public.messages
FOR SELECT
TO authenticated
USING (
    company_id = get_my_company_id() 
    AND (
        get_user_role() IN ('admin', 'dispatcher', 'safetyOfficer')
        OR (
            get_user_role() = 'driver' 
            AND (
                load_id IS NULL
                OR EXISTS (
                    SELECT 1 FROM public.loads 
                    WHERE id = messages.load_id 
                    AND assigned_driver_id = (select auth.uid())
                )
            )
        )
    )
);

-- Refactor driver_locations policy
DROP POLICY IF EXISTS "Company members can view driver locations" ON public.driver_locations;
CREATE POLICY "Company members can view driver locations"
ON public.driver_locations
FOR SELECT
USING (company_id = get_my_company_id()); -- Simplified using optimized helper

-- 4. VACUUM ANALYZE (Informative)
-- Note: Supabase handles autovacuum, but after major indexing it helps to ANALYZE.
ANALYZE public.driver_trips;
ANALYZE public.loads;
ANALYZE public.notifications;
ANALYZE public.messages;
