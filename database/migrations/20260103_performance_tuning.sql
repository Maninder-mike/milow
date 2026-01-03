-- =============================================================================
-- MIGRATION: 20260103_performance_tuning.sql
-- Purpose: Optimizations for scaling to millions of users.
--          1. Enable Trigram extension for fast fuzzy search (ILIKE '%term%')
--          2. Add missing Foreign Key indexes.
--          3. Add GIN indexes for search columns.
-- =============================================================================

-- 1. Enable pg_trgm for "Like %Query%" optimization
-- This allows Postgres to use a GIN index for ILIKE queries with leading wildcards.
create extension if not exists pg_trgm;

-- 2. Create GIN Index for Global Search (Profiles)
-- This turns O(N) sequential scans into O(log N) index scans for user searches.
drop index if exists idx_profiles_full_name_trgm;
create index idx_profiles_full_name_trgm 
on public.profiles 
using gin (full_name gin_trgm_ops);

-- 3. Add Missing Foreign Key Indexes (Prevent "Seq Scan" on Joins)

-- Pickups
create index if not exists idx_pickups_company_id on public.pickups(company_id);

-- Receivers
create index if not exists idx_receivers_company_id on public.receivers(company_id);

-- Vehicle Documents
create index if not exists idx_vehicle_documents_vehicle_id on public.vehicle_documents(vehicle_id);

-- 4. Optimize Message Search
-- Composite index for Inbox queries (sorting by date per user is common)
create index if not exists idx_messages_sender_date 
on public.messages(sender_id, created_at desc);

create index if not exists idx_messages_receiver_date 
on public.messages(receiver_id, created_at desc);

-- =============================================================================
-- PHASE 2: JWT Claims Optimization (Eliminate RLS Subqueries)
-- =============================================================================

-- 5. Enhanced Metadata Sync Function
-- This function now syncs both 'role' and 'company_id' to auth.users.raw_app_meta_data.
-- This allows RLS policies to use `(auth.jwt() ->> 'company_id')` instead of joining tables.
create or replace function public.sync_user_metadata()
returns trigger as $$
begin
  update auth.users
  set raw_app_meta_data = 
      coalesce(raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object(
        'role', new.role,
        'company_id', new.company_id
      )
  where id = new.id;
  return new;
end;
$$ language plpgsql security definer;

-- 6. Update Triggers to Watch for Company ID Changes
drop trigger if exists on_profile_role_change on public.profiles;

-- Create comprehensive trigger for Role OR Company ID changes
drop trigger if exists on_profile_metadata_change on public.profiles;
create trigger on_profile_metadata_change
  after insert or update of role, company_id on public.profiles
  for each row
  execute procedure public.sync_user_metadata();

-- 7. Backfill Metadata (Crucial for existing users)
-- Updates all existing users to have their current company_id in metadata
do $$
declare
  r record;
begin
  for r in select id, role, company_id from public.profiles loop
    update auth.users
    set raw_app_meta_data = 
        coalesce(raw_app_meta_data, '{}'::jsonb) || 
        jsonb_build_object(
          'role', r.role,
          'company_id', r.company_id
        )
    where id = r.id;
  end loop;
end;
$$;
