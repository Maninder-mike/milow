-- Migration: fix_indexes
-- Description: Adds missing covering indexes for foreign keys to improve performance
-- Issue: Addresses "Unindexed foreign keys" linter warnings for vehicles and vehicle_documents tables.

-- 1. vehicle_documents indexes
CREATE INDEX IF NOT EXISTS idx_vehicle_documents_company_id ON public.vehicle_documents(company_id);
-- The linter identified 'truck_documents_truck_id_fkey' but code uses 'vehicle_documents' and 'vehicle_id'.
-- We assume the constraint name might still refer to trucks, but the column is vehicle_id.
CREATE INDEX IF NOT EXISTS idx_vehicle_documents_vehicle_id ON public.vehicle_documents(vehicle_id);

-- 2. vehicles indexes
CREATE INDEX IF NOT EXISTS idx_vehicles_company_id ON public.vehicles(company_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_created_by ON public.vehicles(created_by);

-- 3. Unused Indexes (Commented out for safety, can be uncommented if determined safe to remove)
-- DROP INDEX IF EXISTS public.newsletter_subscribers_created_at_idx;
-- DROP INDEX IF EXISTS public.idx_messages_sender_id;
-- DROP INDEX IF EXISTS public.idx_messages_receiver_id;
-- DROP INDEX IF EXISTS public.idx_notifications_user_id;
-- DROP INDEX IF EXISTS public.idx_notifications_is_read;
-- DROP INDEX IF EXISTS public.idx_companies_name;
-- DROP INDEX IF EXISTS public.idx_profiles_role;
-- DROP INDEX IF EXISTS public.idx_profiles_company_id;
-- DROP INDEX IF EXISTS public.idx_fuel_entries_company_id;
-- DROP INDEX IF EXISTS public.fuel_entries_fuel_date_idx;
-- DROP INDEX IF EXISTS public.projects_is_featured_idx;
