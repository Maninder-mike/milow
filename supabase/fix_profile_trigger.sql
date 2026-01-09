-- Fix for protect_sensitive_profile_fields trigger
-- This allows the service_role (Edge Functions) to bypass the admin check
-- while preserving security for regular users.

CREATE OR REPLACE FUNCTION public.protect_sensitive_profile_fields()
RETURNS TRIGGER AS $$
DECLARE
  current_user_role text;
BEGIN
  -- 1. Allow service_role (Edge Functions) to bypass everything
  -- This is the critical fix for the invite-user function
  IF (auth.role() = 'service_role') THEN
    RETURN NEW;
  END IF;

  -- 2. Check if sensitive fields are being modified
  IF (NEW.role IS DISTINCT FROM OLD.role) OR (NEW.is_verified IS DISTINCT FROM OLD.is_verified) THEN
    
    -- 3. Get the role of the user performing the update
    SELECT role INTO current_user_role
    FROM public.profiles
    WHERE id = auth.uid();

    -- 4. If not admin, raise error
    -- Note: If user is not found (e.g. anon), current_user_role will be null, triggering the error (safe)
    IF current_user_role IS DISTINCT FROM 'admin' THEN
      RAISE EXCEPTION 'Unauthorized: Only admins can change user roles or verification status.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
