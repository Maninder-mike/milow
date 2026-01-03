-- =============================================================================
-- DRIVER VEHICLE ASSIGNMENTS
-- Junction table for tracking vehicle-to-driver assignments with history
-- =============================================================================

-- 1. CREATE TABLE
create table if not exists public.driver_vehicle_assignments (
    id uuid default gen_random_uuid() primary key,
    company_id uuid references public.companies(id) not null,
    driver_id uuid references public.profiles(id) on delete cascade not null,
    vehicle_id uuid references public.vehicles(id) on delete cascade not null,
    assigned_at timestamptz default now() not null,
    unassigned_at timestamptz,
    assigned_by uuid references public.profiles(id),
    is_active boolean generated always as (unassigned_at is null) stored,
    created_at timestamptz default now()
);

-- Add comments
comment on table public.driver_vehicle_assignments is 'Tracks which driver is assigned to which vehicle, with full history';
comment on column public.driver_vehicle_assignments.is_active is 'Computed: true if unassigned_at is null';

-- 2. ENABLE RLS
alter table public.driver_vehicle_assignments enable row level security;

-- 3. INDEXES (Optimized for scale)
create index if not exists idx_dva_driver_active 
    on public.driver_vehicle_assignments (driver_id) 
    where is_active = true;

create index if not exists idx_dva_vehicle_active 
    on public.driver_vehicle_assignments (vehicle_id) 
    where is_active = true;

create index if not exists idx_dva_company 
    on public.driver_vehicle_assignments (company_id);

create index if not exists idx_dva_assigned_at 
    on public.driver_vehicle_assignments (assigned_at desc);

-- 4. RLS POLICIES

-- Select: Company members can view assignments
drop policy if exists "Company members can view assignments" on public.driver_vehicle_assignments;
create policy "Company members can view assignments"
    on public.driver_vehicle_assignments for select using (
        company_id in (select company_id from public.profiles where id = (select auth.uid()))
        or driver_id = (select auth.uid())
    );

-- Insert: Admins/Dispatchers can create assignments
drop policy if exists "Admins can create assignments" on public.driver_vehicle_assignments;
create policy "Admins can create assignments"
    on public.driver_vehicle_assignments for insert with check (
        company_id in (select company_id from public.profiles where id = (select auth.uid()))
        and public.get_my_claim_role() in ('admin', 'dispatcher')
    );

-- Update: Admins/Dispatchers can update (unassign)
drop policy if exists "Admins can update assignments" on public.driver_vehicle_assignments;
create policy "Admins can update assignments"
    on public.driver_vehicle_assignments for update using (
        company_id in (select company_id from public.profiles where id = (select auth.uid()))
        and public.get_my_claim_role() in ('admin', 'dispatcher')
    );

-- Delete: Admins can delete
drop policy if exists "Admins can delete assignments" on public.driver_vehicle_assignments;
create policy "Admins can delete assignments"
    on public.driver_vehicle_assignments for delete using (
        company_id in (select company_id from public.profiles where id = (select auth.uid()))
        and public.get_my_claim_role() = 'admin'
    );

-- 5. TRIGGER: Auto-set company_id from profile
drop trigger if exists set_dva_company_id_trigger on public.driver_vehicle_assignments;
create trigger set_dva_company_id_trigger
    before insert on public.driver_vehicle_assignments
    for each row execute procedure public.set_company_id();

-- 6. FUNCTION: Get current vehicle for a driver
create or replace function public.get_driver_current_vehicle(driver_uuid uuid)
returns table (
    vehicle_id uuid,
    vehicle_number text,
    vehicle_type text,
    assigned_at timestamptz
) as $$
    select 
        v.id as vehicle_id,
        v.vehicle_number,
        v.vehicle_type,
        dva.assigned_at
    from public.driver_vehicle_assignments dva
    join public.vehicles v on v.id = dva.vehicle_id
    where dva.driver_id = driver_uuid
      and dva.is_active = true
    limit 1;
$$ language sql stable security definer set search_path = public;

-- 7. ENABLE REALTIME
alter publication supabase_realtime add table public.driver_vehicle_assignments;
