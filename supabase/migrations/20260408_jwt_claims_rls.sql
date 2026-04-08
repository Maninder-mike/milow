-- Migration Name: 20260408_jwt_claims_rls.sql
-- Description: Optimizes RLS by moving company_id and role into JWT claims (raw_app_metadata).
-- This eliminates subqueries in RLS policies, which is essential for scaling to millions of users.

-- 1. Create or replace the function to sync profile metadata to auth.users
CREATE OR REPLACE FUNCTION public.handle_update_user_claims()
RETURNS TRIGGER AS $$
BEGIN
  -- Update auth.users raw_app_metadata with company_id and role
  UPDATE auth.users
  SET raw_app_metadata = 
    COALESCE(raw_app_metadata, '{}'::jsonb) || 
    jsonb_build_object(
      'company_id', NEW.company_id,
      'role', NEW.role
    )
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create the trigger on public.profiles
DROP TRIGGER IF EXISTS on_profile_update_claims ON public.profiles;
CREATE TRIGGER on_profile_update_claims
  AFTER INSERT OR UPDATE OF company_id, role ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.handle_update_user_claims();

-- 3. Update Existing auth.users (One-time sync for current users)
UPDATE auth.users
SET raw_app_metadata = 
  COALESCE(auth.users.raw_app_metadata, '{}'::jsonb) || 
  jsonb_build_object(
    'company_id', p.company_id,
    'role', p.role
  )
FROM public.profiles p
WHERE auth.users.id = p.id;

-- 4. Re-implement RLS Policies using JWT Claims

-- public.driver_trips
DROP POLICY IF EXISTS "Users can view own trips" ON public.driver_trips;
CREATE POLICY "Users can view own trips" ON public.driver_trips 
  FOR SELECT TO authenticated 
  USING (
    auth.uid() = user_id OR 
    (company_id IS NOT NULL AND company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid)
  );

-- public.fuel_entries
DROP POLICY IF EXISTS "Users can view own fuel entries" ON public.fuel_entries;
CREATE POLICY "Users can view own fuel entries" ON public.fuel_entries 
  FOR SELECT TO authenticated 
  USING (
    auth.uid() = user_id OR 
    (company_id IS NOT NULL AND company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid)
  );

-- public.loads
DROP POLICY IF EXISTS "Company members can view loads" ON public.loads;
CREATE POLICY "Company members can view loads" ON public.loads
  FOR SELECT TO authenticated
  USING (
    company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid
  );

DROP POLICY IF EXISTS "Dispatchers can insert loads" ON public.loads;
CREATE POLICY "Dispatchers can insert loads" ON public.loads
  FOR INSERT TO authenticated
  WITH CHECK (
    company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid
    AND (auth.jwt() -> 'app_metadata' ->> 'role') IN ('admin', 'dispatcher', 'superadmin', 'owner')
  );

DROP POLICY IF EXISTS "Users can update loads" ON public.loads;
CREATE POLICY "Users can update loads" ON public.loads
  FOR UPDATE TO authenticated
  USING (
    company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid
    AND (
        (auth.jwt() -> 'app_metadata' ->> 'role') IN ('admin', 'dispatcher', 'superadmin', 'owner')
        OR auth.uid() = assigned_driver_id
    )
  );

DROP POLICY IF EXISTS "Dispatchers can delete loads" ON public.loads;
CREATE POLICY "Dispatchers can delete loads" ON public.loads
  FOR DELETE TO authenticated
  USING (
    company_id = (auth.jwt() -> 'app_metadata' ->> 'company_id')::uuid
    AND (auth.jwt() -> 'app_metadata' ->> 'role') IN ('admin', 'dispatcher', 'superadmin', 'owner')
  );
