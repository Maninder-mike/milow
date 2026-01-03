-- =============================================================================
-- MIGRATION: 20260103_enterprise_upgrade.sql
-- Purpose: Implement Enterprise Standards (Audit, Soft Delete, Integrity)
-- =============================================================================

-- =============================================================================
-- PHASE 1: AUDIT LOGGING (Compliance)
-- =============================================================================

-- 1. Create Audit Logs Table
create table if not exists public.audit_logs (
    id uuid default gen_random_uuid() primary key,
    table_name text not null,
    record_id uuid not null,
    operation text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
    old_values jsonb,
    new_values jsonb,
    changed_by uuid references auth.users(id),
    changed_at timestamptz default now(),
    -- Metadata constraints
    company_id uuid -- Denormalized for easy filtering
);

-- 2. Enable RLS on Audit Logs (Admins Only)
alter table public.audit_logs enable row level security;

drop policy if exists "Admins can view company audit logs" on public.audit_logs;
create policy "Admins can view company audit logs"
    on public.audit_logs for select
    using (
        (auth.jwt() ->> 'company_id')::uuid = company_id
        and 
        public.get_my_claim_role() = 'admin'
    );

-- 3. Generic Audit Trigger Function
create or replace function public.log_audit_event()
returns trigger as $$
declare
    v_old_data jsonb;
    v_new_data jsonb;
    v_company_id uuid;
begin
    -- Determine Company ID (Try new, then old, then fallback)
    if (TG_OP = 'INSERT') then
        v_new_data = to_jsonb(NEW);
        v_company_id = NEW.company_id;
    elsif (TG_OP = 'UPDATE') then
        v_old_data = to_jsonb(OLD);
        v_new_data = to_jsonb(NEW);
        v_company_id = NEW.company_id;
    elsif (TG_OP = 'DELETE') then
        v_old_data = to_jsonb(OLD);
        v_company_id = OLD.company_id;
    end if;

    insert into public.audit_logs (
        table_name,
        record_id,
        operation,
        old_values,
        new_values,
        changed_by,
        company_id
    ) values (
        TG_TABLE_NAME::text,
        coalesce(NEW.id, OLD.id),
        TG_OP,
        v_old_data,
        v_new_data,
        auth.uid(),
        v_company_id
    );
    
    return null; -- Result is ignored for AFTER triggers
end;
$$ language plpgsql security definer;

-- 4. Attach Audit Triggers to Critical Tables
-- Trips
drop trigger if exists audit_trips_trigger on public.trips;
create trigger audit_trips_trigger
    after insert or update or delete on public.trips
    for each row execute procedure public.log_audit_event();

-- Customers
drop trigger if exists audit_customers_trigger on public.customers;
create trigger audit_customers_trigger
    after insert or update or delete on public.customers
    for each row execute procedure public.log_audit_event();

-- Vehicles
drop trigger if exists audit_vehicles_trigger on public.vehicles;
create trigger audit_vehicles_trigger
    after insert or update or delete on public.vehicles
    for each row execute procedure public.log_audit_event();

-- Profiles (High Value)
drop trigger if exists audit_profiles_trigger on public.profiles;
create trigger audit_profiles_trigger
    after insert or update or delete on public.profiles
    for each row execute procedure public.log_audit_event();


-- =============================================================================
-- PHASE 2: SOFT DELETES (Recovery)
-- =============================================================================

-- Helper Function to add soft delete column safely
create or replace function public.add_soft_delete(tbl text) returns void as $$
begin
    execute format('alter table public.%I add column if not exists deleted_at timestamptz', tbl);
end;
$$ language plpgsql;

-- 1. Add deleted_at columns
select public.add_soft_delete('trips');
select public.add_soft_delete('customers');
select public.add_soft_delete('vehicles');
select public.add_soft_delete('pickups');
select public.add_soft_delete('receivers');

-- 2. Update RLS Policies to HIDE deleted items
-- NOTE: We must drop and recreate the SELECT policies.

-- Trips
drop policy if exists "Users can view own trips" on public.trips;
create policy "Users can view own trips" on public.trips
    for select to authenticated 
    using (auth.uid() = user_id and deleted_at is null);

-- Customers
drop policy if exists "Company members can view customers" on public.customers;
create policy "Company members can view customers"
    on public.customers for select 
    using (company_id = (auth.jwt() ->> 'company_id')::uuid and deleted_at is null);

-- Vehicles
drop policy if exists "Company members can view vehicles" on public.vehicles;
create policy "Company members can view vehicles"
    on public.vehicles for select 
    using (company_id = (auth.jwt() ->> 'company_id')::uuid and deleted_at is null);


-- =============================================================================
-- PHASE 3: DATA INTEGRITY (Strict FKs)
-- =============================================================================

-- 0. Standardize Vehicle Schema (Fix "vehicle_number" vs "truck_number")
do $$
begin
    if exists(select 1 from information_schema.columns where table_name = 'vehicles' and column_name = 'vehicle_number') then
        alter table public.vehicles rename column vehicle_number to truck_number;
    end if;
end $$;

-- 1. Enhance Trips with Vehicle Link
alter table public.trips 
add column if not exists vehicle_id uuid references public.vehicles(id);

create index if not exists idx_trips_vehicle_id on public.trips(vehicle_id);

-- 2. Backfill: Try to find vehicle_id by matching truck_number (Case insensitive)
update public.trips t
set vehicle_id = v.id
from public.vehicles v
where lower(t.truck_number) = lower(v.truck_number)
and t.company_id = v.company_id
and t.vehicle_id is null;

-- 3. Enhance Fuel Entries with Vehicle Link
alter table public.fuel_entries 
add column if not exists vehicle_id uuid references public.vehicles(id);

create index if not exists idx_fuel_entries_vehicle_id on public.fuel_entries(vehicle_id);

-- 4. Backfill Fuel Entries
update public.fuel_entries f
set vehicle_id = v.id
from public.vehicles v
where lower(f.truck_number) = lower(v.truck_number)
and f.company_id = v.company_id
and f.vehicle_id is null;

-- NOTE: We do NOT add a 'NOT NULL' constraint yet, to prevent breaking old apps
-- that haven't updated to send vehicle_id.
