-- 1. Enable RLS on the table (good practice, though likely already on)
ALTER TABLE "public"."vehicles" ENABLE ROW LEVEL SECURITY;

-- 2. Drop potential conflicting policies to ensure a clean slate
DROP POLICY IF EXISTS "Enable read access for users based on company_id" ON "public"."vehicles";
DROP POLICY IF EXISTS "Enable insert for users based on company_id" ON "public"."vehicles";
DROP POLICY IF EXISTS "Enable update for users based on company_id" ON "public"."vehicles";
DROP POLICY IF EXISTS "Enable delete for users based on company_id" ON "public"."vehicles";
DROP POLICY IF EXISTS "Allow all for authenticated" ON "public"."vehicles";

-- 3. Create the SELECT policy
-- This allows any authenticated user to see vehicles that belong to their company.
CREATE POLICY "Enable read access for users based on company_id"
ON "public"."vehicles"
FOR SELECT
TO authenticated
USING (
  company_id = (
    SELECT company_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  )
);

-- 4. Create INSERT policy
CREATE POLICY "Enable insert for users based on company_id"
ON "public"."vehicles"
FOR INSERT
TO authenticated
WITH CHECK (
  company_id = (
    SELECT company_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  )
);

-- 5. Create UPDATE policy
CREATE POLICY "Enable update for users based on company_id"
ON "public"."vehicles"
FOR UPDATE
TO authenticated
USING (
  company_id = (
    SELECT company_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  )
);

-- 6. Create DELETE policy
CREATE POLICY "Enable delete for users based on company_id"
ON "public"."vehicles"
FOR DELETE
TO authenticated
USING (
  company_id = (
    SELECT company_id 
    FROM public.profiles 
    WHERE id = auth.uid()
  )
);
