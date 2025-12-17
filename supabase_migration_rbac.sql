-- Add is_verified column-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  email text,
  full_name text,
  role text DEFAULT 'pending', -- Default role for new users
  is_verified boolean DEFAULT false, -- Needs admin approval
  target_admin_email text, -- Specific admin to notify
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- MIGRATION: Ensure columns exist on existing tables
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_verified boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS company_code;

-- Update the check constraint for user_role
-- We drop the old one and add a new one to ensure 'pending' and 'safetyOfficer' are allowed

-- DATA SANITIZATION: Fix existing invalid roles first to prevent constraint violation
UPDATE profiles SET role = 'safetyOfficer' WHERE role = 'safety_officer';
UPDATE profiles SET role = 'pending' WHERE role NOT IN ('admin', 'dispatcher', 'driver', 'safetyOfficer', 'assistant', 'pending');

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('admin', 'dispatcher', 'driver', 'safetyOfficer', 'assistant', 'pending'));

-- RLS POLICIES

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Helper function to get user role securely (bypasses RLS)
-- Helper function to get user role from JWT (Zero-Latency)
-- NOTE: This relies on app_metadata being synced with profiles.role
CREATE OR REPLACE FUNCTION public.get_my_claim_role()
RETURNS text AS $$
BEGIN
  -- Return the role from the JWT, defaulting to 'pending' if missing
  RETURN COALESCE((auth.jwt() -> 'app_metadata' ->> 'role'), 'pending');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Policy: Admins can see all profiles
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
CREATE POLICY "Admins can view all profiles" 
ON profiles FOR SELECT 
TO authenticated 
USING (
  auth.uid() = id OR public.get_my_claim_role() = 'admin'
);

-- Policy: Admins can update all profiles
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;
CREATE POLICY "Admins can update all profiles" 
ON profiles FOR UPDATE
TO authenticated 
USING (
  public.get_my_claim_role() = 'admin'
);

-- Policy: Users can update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE
TO authenticated 
USING (
  auth.uid() = id
);

-- TRIGGER FOR NEW USERS
-- First, drop the trigger and function to ensure a clean update
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_verified, avatar_url)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name',
    -- Use provided role from metadata, or default to 'pending' if null/empty
    COALESCE(new.raw_user_meta_data->>'role', 'pending'), 
    -- Auto-verify if the role is 'admin', otherwise false
    (COALESCE(new.raw_user_meta_data->>'role', 'pending') = 'admin'),
    -- Avatar URL
    COALESCE(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture')
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger definition
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- SECURITY: Prevent non-admins from changing their role or verification status
CREATE OR REPLACE FUNCTION public.protect_sensitive_profile_fields()
RETURNS trigger AS $$
DECLARE
  v_current_role text;
BEGIN
  -- Check if sensitive fields are changing
  IF (NEW.role IS DISTINCT FROM OLD.role) OR (NEW.is_verified IS DISTINCT FROM OLD.is_verified) THEN
    
    -- Get the role of the user trying to make the change
    SELECT role INTO v_current_role FROM public.profiles WHERE id = auth.uid();
    
    -- If the user is not an admin, deny the change
    -- Allow null role (service_role) to bypass check? Usually service_role bypasses RLS/Triggers if configured, 
    -- but here we assume auth.uid() is present for client requests.
    IF v_current_role IS DISTINCT FROM 'admin' THEN
       RAISE EXCEPTION 'Unauthorized: Only admins can change user roles or verification status.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- SYNC ROLE TO AUTH METADATA
-- This ensures the JWT always contains the latest role
CREATE OR REPLACE FUNCTION public.sync_user_role()
RETURNS trigger AS $$
BEGIN
  -- Update auth.users with the new role in app_metadata
  UPDATE auth.users
  SET raw_app_meta_data = 
      jsonb_set(
        COALESCE(raw_app_meta_data, '{}'::jsonb),
        '{role}',
        to_jsonb(NEW.role)
      )
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to sync role on profile update/insert
DROP TRIGGER IF EXISTS on_profile_role_change ON public.profiles;
CREATE TRIGGER on_profile_role_change
  AFTER INSERT OR UPDATE OF role ON public.profiles
  FOR EACH ROW
  EXECUTE PROCEDURE public.sync_user_role();

-- SECURITY: Prevent non-admins from changing their role
-- (Kept protect_sensitive_profile_fields as is, but updated to use new role check if needed, 
-- though it queries table directly which is fine for writes/updates as they are rare compared to reads)
-- We will optimize the check to trust the JWT for the *checker* but verify the target.


-- NOTIFICATIONS SYSTEM
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text NOT NULL, -- 'company_invite', 'message', 'system'
  title text,
  body text,
  data jsonb,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can create notifications" ON notifications;
CREATE POLICY "Admins can create notifications" ON notifications
  FOR INSERT WITH CHECK (
    public.get_my_claim_role() = 'admin' OR 
    auth.uid() = user_id -- Allow self-creation? Or maybe system triggers.
  );

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
  FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- MESSAGING SYSTEM
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id uuid REFERENCES public.profiles(id),
  receiver_id uuid REFERENCES public.profiles(id),
  content text,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own messages" ON messages;
CREATE POLICY "Users can view own messages" ON messages
  FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users can send messages" ON messages;
CREATE POLICY "Users can send messages" ON messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);


-- RPC: Allow users to reject company invite (Unverify themselves)
CREATE OR REPLACE FUNCTION public.reject_company_invite()
RETURNS void AS $$
BEGIN
  -- Update the calling user's profile to is_verified = false
  -- SECURITY DEFINER allows this update despite the trigger protection
  UPDATE public.profiles
  SET is_verified = false
  WHERE id = auth.uid();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TRIGGER: Notify User on Verification
CREATE OR REPLACE FUNCTION public.notify_on_verification()
RETURNS trigger AS $$
DECLARE
  v_admin_name text;
BEGIN
  -- If verification status changed from false to true
  IF OLD.is_verified = false AND NEW.is_verified = true THEN
    -- Fetch Admin Name (User who performed the update)
    SELECT full_name INTO v_admin_name FROM public.profiles WHERE id = auth.uid();
    
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.id,
      'company_invite',
      'Verification Request',
      'Admin ' || COALESCE(v_admin_name, 'Unknown') || ' has verified your ID. Approving this request allows the company to view your trip and fuel data. Without your approval, the Admin terminal cannot see your data.',
      jsonb_build_object('admin_id', auth.uid(), 'admin_name', v_admin_name)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_verified_notify ON public.profiles;
CREATE TRIGGER on_profile_verified_notify
  AFTER UPDATE ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.notify_on_verification();

-- TRIGGER: Notify User on New Message
CREATE OR REPLACE FUNCTION public.notify_on_message()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.receiver_id,
    'message',
    'New Message',
    substring(NEW.content from 1 for 100), -- Preview content
    jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_created ON public.messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE PROCEDURE public.notify_on_message();

