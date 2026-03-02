-- Migration Name: 20260302_critical_rls_fixes.sql

-- 1. `driver_trips` - allow company members to select
DROP POLICY IF EXISTS "Users can view own trips" ON public.driver_trips;
CREATE POLICY "Users can view own trips" ON public.driver_trips 
  FOR SELECT TO authenticated 
  USING (
    auth.uid() = user_id OR 
    (company_id IS NOT NULL AND company_id IN (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
    ))
  );

-- 2. `fuel_entries` - allow company members to select
DROP POLICY IF EXISTS "Users can view own fuel entries" ON public.fuel_entries;
CREATE POLICY "Users can view own fuel entries" ON public.fuel_entries 
  FOR SELECT TO authenticated 
  USING (
    auth.uid() = user_id OR 
    (company_id IS NOT NULL AND company_id IN (
        SELECT company_id FROM public.profiles WHERE id = auth.uid()
    ))
  );

-- 3. `loads` - implement RLS
ALTER TABLE public.loads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Company members can view loads" ON public.loads;
CREATE POLICY "Company members can view loads" ON public.loads
  FOR SELECT TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "Dispatchers can insert loads" ON public.loads;
CREATE POLICY "Dispatchers can insert loads" ON public.loads
  FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('admin', 'dispatcher', 'superadmin', 'owner')
    )
  );

DROP POLICY IF EXISTS "Users can update loads" ON public.loads;
CREATE POLICY "Users can update loads" ON public.loads
  FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
    AND (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('admin', 'dispatcher', 'superadmin', 'owner')
        )
        OR auth.uid() = assigned_driver_id
    )
  );

DROP POLICY IF EXISTS "Dispatchers can delete loads" ON public.loads;
CREATE POLICY "Dispatchers can delete loads" ON public.loads
  FOR DELETE TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role IN ('admin', 'dispatcher', 'superadmin', 'owner')
    )
  );

-- 4. Triggers to automatically set `company_id`
DROP TRIGGER IF EXISTS set_messages_company_id_trigger ON public.messages;
CREATE TRIGGER set_messages_company_id_trigger
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE PROCEDURE public.set_company_id();

DROP TRIGGER IF EXISTS set_loads_company_id_trigger ON public.loads;
CREATE TRIGGER set_loads_company_id_trigger
  BEFORE INSERT ON public.loads
  FOR EACH ROW EXECUTE PROCEDURE public.set_company_id();
