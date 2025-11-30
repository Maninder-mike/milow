-- Create a table for public profiles
create table profiles (
  id uuid references auth.users not null primary key,
  updated_at timestamp with time zone,
  full_name text,
  avatar_url text,
  website text,
  address text,
  country text,
  phone text,
  email text,
  company_name text,
  company_code text
);

-- Set up Row Level Security (RLS)
-- See https://supabase.com/docs/guides/auth/row-level-security for more details.
alter table profiles enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check ((select auth.uid()) = id);

create policy "Users can update own profile." on profiles
  for update using ((select auth.uid()) = id);

-- This triggers a reaction whenever a new user is created
-- Create or replace to avoid duplicate definition errors
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Recreate trigger idempotently
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Create a public storage bucket for avatars (run once)
-- Note: If bucket already exists, this section can be skipped.
-- select * from storage.buckets where name = 'avatars';
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Allow public read on the avatars bucket and owner write
create policy "Public read for avatars"
  on storage.objects for select
  using ( bucket_id = 'avatars' );

create policy "Users can upload their avatars"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update their avatars"
  on storage.objects for update
  using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their avatars"
  on storage.objects for delete
  using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );
