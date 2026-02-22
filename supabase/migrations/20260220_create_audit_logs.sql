-- Create Audit Logs Table
create table if not exists public.audit_logs (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id),
    action text not null,
    resource text not null,
    details text,
    metadata jsonb,
    ip_address text,
    created_at timestamptz default now()
);

-- Enable RLS
alter table public.audit_logs enable row level security;

-- Policies

-- 1. Insert: Authenticated users can log their own actions.
create policy "Users can insert audit logs"
    on public.audit_logs
    for insert
    to authenticated
    with check (auth.uid() = user_id);

-- 2. Select: Only Admins can view audit logs.
-- Using the existing helper function get_my_claim_role() if available, or querying profiles.
create policy "Admins can view audit logs"
    on public.audit_logs
    for select
    to authenticated
    using (
        exists (
            select 1 from public.profiles
            where profiles.id = auth.uid()
            and profiles.role = 'admin'
        )
    );

-- 3. No Update/Delete: Logs are immutable.
-- No policies for update/delete means they are implicitly denied by default RLS.

-- Indexes for performance
create index if not exists idx_audit_logs_user_id on public.audit_logs(user_id);
create index if not exists idx_audit_logs_resource on public.audit_logs(resource);
create index if not exists idx_audit_logs_created_at on public.audit_logs(created_at desc);
