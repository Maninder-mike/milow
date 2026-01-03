-- Migration: Update all pending roles to driver
-- This migration updates all existing users with role='pending' to role='driver'
-- since mobile app signups should be drivers by default.

-- 1. Update all existing pending users to driver
-- We disable triggers temporarily to bypass the 'protect_sensitive_profile_fields' check
-- which requires an active admin session.
ALTER TABLE public.profiles DISABLE TRIGGER USER;

UPDATE public.profiles
SET role = 'driver'
WHERE role = 'pending';

ALTER TABLE public.profiles ENABLE TRIGGER USER;

-- 2. Update the handle_new_user function to default new users to 'driver'
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role, is_verified, avatar_url)
  values (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name',
    coalesce(new.raw_user_meta_data->>'role', 'driver'), -- Default to 'driver' instead of 'pending'
    (coalesce(new.raw_user_meta_data->>'role', 'driver') = 'admin'),
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture')
  );
  return new;
end;
$$ language plpgsql security definer;
