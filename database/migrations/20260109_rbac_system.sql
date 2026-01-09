-- =============================================================================
-- RBAC SYSTEM MIGRATION
-- Created: 2026-01-09
-- Purpose: Add dynamic roles, permissions, and user credential management
-- =============================================================================

-- ============================================
-- 1. PERMISSIONS TABLE (Catalog of all permissions)
-- ============================================
CREATE TABLE IF NOT EXISTS public.permissions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    code text UNIQUE NOT NULL,           -- e.g., 'vehicles.read', 'trips.delete'
    category text NOT NULL,              -- e.g., 'vehicles', 'trips', 'users'
    description text,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read permissions (needed for UI)
DROP POLICY IF EXISTS "Authenticated users can view permissions" ON public.permissions;
CREATE POLICY "Authenticated users can view permissions" ON public.permissions
    FOR SELECT TO authenticated USING (true);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_permissions_category ON public.permissions(category);
CREATE INDEX IF NOT EXISTS idx_permissions_code ON public.permissions(code);

-- ============================================
-- 2. ROLES TABLE (Custom roles per company)
-- ============================================
CREATE TABLE IF NOT EXISTS public.roles (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    is_system_role boolean DEFAULT false,  -- Cannot delete system roles
    metadata jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(company_id, name)
);

-- Enable RLS
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;

-- Company members can view their company's roles
DROP POLICY IF EXISTS "Company members can view roles" ON public.roles;
CREATE POLICY "Company members can view roles" ON public.roles
    FOR SELECT TO authenticated USING (
        company_id IN (SELECT company_id FROM public.profiles WHERE id = (SELECT auth.uid()))
    );

-- Only admins can manage roles
DROP POLICY IF EXISTS "Admins can manage roles" ON public.roles;
CREATE POLICY "Admins can manage roles" ON public.roles
    FOR ALL TO authenticated USING (
        company_id IN (SELECT company_id FROM public.profiles WHERE id = (SELECT auth.uid()))
        AND (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())) = 'admin'
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_roles_company_id ON public.roles(company_id);

-- ============================================
-- 3. ROLE_PERMISSIONS (Junction table)
-- ============================================
CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id uuid REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id uuid REFERENCES public.permissions(id) ON DELETE CASCADE,
    can_read boolean DEFAULT true,
    can_write boolean DEFAULT false,
    can_delete boolean DEFAULT false,
    PRIMARY KEY (role_id, permission_id)
);

-- Enable RLS
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- Company members can view role permissions for their company's roles
DROP POLICY IF EXISTS "Company members can view role permissions" ON public.role_permissions;
CREATE POLICY "Company members can view role permissions" ON public.role_permissions
    FOR SELECT TO authenticated USING (
        role_id IN (
            SELECT id FROM public.roles 
            WHERE company_id IN (SELECT company_id FROM public.profiles WHERE id = (SELECT auth.uid()))
        )
    );

-- Admins can manage role permissions
DROP POLICY IF EXISTS "Admins can manage role permissions" ON public.role_permissions;
CREATE POLICY "Admins can manage role permissions" ON public.role_permissions
    FOR ALL TO authenticated USING (
        role_id IN (
            SELECT id FROM public.roles 
            WHERE company_id IN (SELECT company_id FROM public.profiles WHERE id = (SELECT auth.uid()))
        )
        AND (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())) = 'admin'
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON public.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_id ON public.role_permissions(permission_id);

-- ============================================
-- 4. USER_CREDENTIALS (Admin-generated accounts)
-- ============================================
CREATE TABLE IF NOT EXISTS public.user_credentials (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
    generated_username text UNIQUE NOT NULL,
    must_change_password boolean DEFAULT true,
    expires_at timestamptz,
    created_by uuid REFERENCES public.profiles(id),
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.user_credentials ENABLE ROW LEVEL SECURITY;

-- Users can view their own credentials
DROP POLICY IF EXISTS "Users can view own credentials" ON public.user_credentials;
CREATE POLICY "Users can view own credentials" ON public.user_credentials
    FOR SELECT TO authenticated USING (profile_id = (SELECT auth.uid()));

-- Admins can view/manage credentials for their company
DROP POLICY IF EXISTS "Admins can manage credentials" ON public.user_credentials;
CREATE POLICY "Admins can manage credentials" ON public.user_credentials
    FOR ALL TO authenticated USING (
        profile_id IN (
            SELECT id FROM public.profiles 
            WHERE company_id IN (SELECT company_id FROM public.profiles WHERE id = (SELECT auth.uid()))
        )
        AND (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())) = 'admin'
    );

-- Index
CREATE INDEX IF NOT EXISTS idx_user_credentials_profile_id ON public.user_credentials(profile_id);
CREATE INDEX IF NOT EXISTS idx_user_credentials_username ON public.user_credentials(generated_username);

-- ============================================
-- 5. ADD role_id TO PROFILES (Optional FK)
-- ============================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles' 
        AND column_name = 'role_id'
    ) THEN
        ALTER TABLE public.profiles ADD COLUMN role_id uuid REFERENCES public.roles(id);
        CREATE INDEX idx_profiles_role_id ON public.profiles(role_id);
    END IF;
END $$;

-- ============================================
-- 6. SEED PERMISSIONS
-- ============================================
INSERT INTO public.permissions (code, category, description) VALUES
    -- Dashboard
    ('dashboard.view', 'dashboard', 'View dashboard'),
    
    -- Vehicles
    ('vehicles.read', 'vehicles', 'View vehicles'),
    ('vehicles.write', 'vehicles', 'Create and edit vehicles'),
    ('vehicles.delete', 'vehicles', 'Delete vehicles'),
    
    -- Trips
    ('trips.read', 'trips', 'View trips'),
    ('trips.write', 'trips', 'Create and edit trips'),
    ('trips.delete', 'trips', 'Delete trips'),
    
    -- Fuel
    ('fuel.read', 'fuel', 'View fuel entries'),
    ('fuel.write', 'fuel', 'Create and edit fuel entries'),
    ('fuel.delete', 'fuel', 'Delete fuel entries'),
    
    -- Drivers
    ('drivers.read', 'drivers', 'View drivers'),
    ('drivers.write', 'drivers', 'Create and edit drivers'),
    ('drivers.delete', 'drivers', 'Delete drivers'),
    
    -- Customers
    ('customers.read', 'customers', 'View customers'),
    ('customers.write', 'customers', 'Create and edit customers'),
    ('customers.delete', 'customers', 'Delete customers'),
    
    -- Loads/Dispatch
    ('loads.read', 'loads', 'View loads'),
    ('loads.write', 'loads', 'Create and edit loads'),
    ('loads.delete', 'loads', 'Delete loads'),
    ('loads.assign', 'loads', 'Assign loads to drivers'),
    
    -- Users
    ('users.read', 'users', 'View users'),
    ('users.write', 'users', 'Create and edit users'),
    ('users.delete', 'users', 'Delete users'),
    ('users.invite', 'users', 'Invite new users'),
    
    -- Roles & Permissions
    ('roles.read', 'admin', 'View roles'),
    ('roles.write', 'admin', 'Create and edit roles'),
    ('roles.delete', 'admin', 'Delete roles'),
    
    -- Settings
    ('settings.view', 'admin', 'View settings'),
    ('settings.manage', 'admin', 'Manage company settings'),
    
    -- Reports
    ('reports.view', 'reports', 'View reports'),
    ('reports.export', 'reports', 'Export reports'),
    
    -- Financials
    ('financials.read', 'financials', 'View financial data'),
    ('financials.write', 'financials', 'Edit financial data')
ON CONFLICT (code) DO NOTHING;

-- ============================================
-- 7. HELPER FUNCTION: Check Permission
-- ============================================
CREATE OR REPLACE FUNCTION public.has_permission(
    p_user_id uuid,
    p_permission_code text,
    p_action text DEFAULT 'read'  -- 'read', 'write', 'delete'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_has_permission boolean := false;
    v_role_id uuid;
    v_legacy_role text;
BEGIN
    -- Get user's role_id and legacy role
    SELECT role_id, role INTO v_role_id, v_legacy_role
    FROM public.profiles WHERE id = p_user_id;
    
    -- Admin always has all permissions (backwards compat)
    IF v_legacy_role = 'admin' THEN
        RETURN true;
    END IF;
    
    -- Check new role-based permissions
    IF v_role_id IS NOT NULL THEN
        SELECT 
            CASE p_action
                WHEN 'read' THEN rp.can_read
                WHEN 'write' THEN rp.can_write
                WHEN 'delete' THEN rp.can_delete
                ELSE false
            END INTO v_has_permission
        FROM public.role_permissions rp
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE rp.role_id = v_role_id AND p.code = p_permission_code;
    END IF;
    
    RETURN COALESCE(v_has_permission, false);
END;
$$;

-- ============================================
-- 8. HELPER FUNCTION: Get User Permissions
-- ============================================
CREATE OR REPLACE FUNCTION public.get_user_permissions(p_user_id uuid)
RETURNS TABLE (
    permission_code text,
    can_read boolean,
    can_write boolean,
    can_delete boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role_id uuid;
    v_legacy_role text;
BEGIN
    -- Get user's role_id and legacy role
    SELECT role_id, role INTO v_role_id, v_legacy_role
    FROM public.profiles WHERE id = p_user_id;
    
    -- Admin gets all permissions
    IF v_legacy_role = 'admin' THEN
        RETURN QUERY
        SELECT p.code, true, true, true
        FROM public.permissions p;
        RETURN;
    END IF;
    
    -- Return role-based permissions
    IF v_role_id IS NOT NULL THEN
        RETURN QUERY
        SELECT p.code, rp.can_read, rp.can_write, rp.can_delete
        FROM public.role_permissions rp
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE rp.role_id = v_role_id;
    END IF;
    
    RETURN;
END;
$$;

-- ============================================
-- 9. TRIGGER: Update timestamps
-- ============================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_roles_updated_at ON public.roles;
CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON public.roles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
