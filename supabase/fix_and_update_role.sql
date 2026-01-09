-- 1. Fix the trigger function first (idempotent, safe to run again)
CREATE OR REPLACE FUNCTION public.protect_sensitive_profile_fields()
RETURNS TRIGGER AS $$
DECLARE
  current_user_role text;
BEGIN
  -- 1. Allow service_role (Edge Functions) AND System/Dashboard (NULL auth.uid) to bypass
  IF (auth.role() = 'service_role' OR auth.uid() IS NULL) THEN
    RETURN NEW;
  END IF;

  -- 2. Check if sensitive fields are being modified
  IF (NEW.role IS DISTINCT FROM OLD.role) OR (NEW.is_verified IS DISTINCT FROM OLD.is_verified) THEN
    
    -- 3. Get the role of the user performing the update
    SELECT role INTO current_user_role
    FROM public.profiles
    WHERE id = auth.uid();

    -- 4. If not admin, raise error
    IF current_user_role IS DISTINCT FROM 'admin' THEN
      RAISE EXCEPTION 'Unauthorized: Only admins can change user roles or verification status.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update the 3 specified users to 'driver'
UPDATE public.profiles
SET 
  role = 'driver',
  is_verified = true
WHERE id IN (
  '05c64730-3b20-493e-b8dd-3365df940e14',
  '865f4d42-5cdf-4080-9809-cc4d44c6e349',
  '8f01294c-5401-4269-80af-20fd11a75546'
);
