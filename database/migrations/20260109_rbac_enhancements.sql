-- =============================================================================
-- RBAC ENHANCEMENTS MIGRATION
-- Created: 2026-01-09
-- Purpose: Add audit logging, role hierarchy, and permission caching support
-- =============================================================================

-- ============================================
-- 1. AUDIT LOG TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.permission_audit_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    action text NOT NULL,  -- 'role.created', 'role.updated', 'user.invited', 'permission.modified'
    target_type text,      -- 'role', 'user', 'permission'
    target_id uuid,
    target_name text,      -- Human-readable name for the target
    metadata jsonb DEFAULT '{}',
    ip_address text,
    user_agent text,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.permission_audit_logs ENABLE ROW LEVEL SECURITY;

-- Admins can view audit logs for their company
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.permission_audit_logs;
CREATE POLICY "Admins can view audit logs" ON public.permission_audit_logs
    FOR SELECT TO authenticated USING (
        actor_id IN (
            SELECT id FROM public.profiles 
            WHERE company_id IN (SELECT company_id FROM public.profiles WHERE id = (SELECT auth.uid()))
        )
        AND (SELECT role FROM public.profiles WHERE id = (SELECT auth.uid())) = 'admin'
    );

-- Anyone can insert (for Edge Functions)
DROP POLICY IF EXISTS "Service can insert audit logs" ON public.permission_audit_logs;
CREATE POLICY "Service can insert audit logs" ON public.permission_audit_logs
    FOR INSERT TO authenticated WITH CHECK (true);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON public.permission_audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target_type ON public.permission_audit_logs(target_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.permission_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.permission_audit_logs(action);

-- ============================================
-- 2. ROLE HIERARCHY (parent_role_id)
-- ============================================
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'roles' 
        AND column_name = 'parent_role_id'
    ) THEN
        ALTER TABLE public.roles ADD COLUMN parent_role_id uuid REFERENCES public.roles(id);
        CREATE INDEX idx_roles_parent_id ON public.roles(parent_role_id);
        COMMENT ON COLUMN public.roles.parent_role_id IS 'Inherit permissions from parent role';
    END IF;
END $$;

-- ============================================
-- 3. HELPER FUNCTION: Check Permission with Hierarchy
-- ============================================
CREATE OR REPLACE FUNCTION public.has_permission_with_hierarchy(
    p_user_id uuid,
    p_permission_code text,
    p_action text DEFAULT 'read'
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
    v_current_role_id uuid;
    v_depth int := 0;
BEGIN
    -- Get user's role_id and legacy role
    SELECT role_id, role INTO v_role_id, v_legacy_role
    FROM public.profiles WHERE id = p_user_id;
    
    -- Admin always has all permissions
    IF v_legacy_role = 'admin' THEN
        RETURN true;
    END IF;
    
    -- Check permissions through role hierarchy (max 5 levels)
    v_current_role_id := v_role_id;
    WHILE v_current_role_id IS NOT NULL AND v_depth < 5 LOOP
        SELECT 
            CASE p_action
                WHEN 'read' THEN rp.can_read
                WHEN 'write' THEN rp.can_write
                WHEN 'delete' THEN rp.can_delete
                ELSE false
            END INTO v_has_permission
        FROM public.role_permissions rp
        JOIN public.permissions p ON p.id = rp.permission_id
        WHERE rp.role_id = v_current_role_id AND p.code = p_permission_code;
        
        -- If found permission, return it
        IF v_has_permission IS NOT NULL AND v_has_permission THEN
            RETURN true;
        END IF;
        
        -- Move to parent role
        SELECT parent_role_id INTO v_current_role_id
        FROM public.roles WHERE id = v_current_role_id;
        
        v_depth := v_depth + 1;
    END LOOP;
    
    RETURN false;
END;
$$;

-- ============================================
-- 4. HELPER FUNCTION: Log Audit Event
-- ============================================
CREATE OR REPLACE FUNCTION public.log_audit_event(
    p_actor_id uuid,
    p_action text,
    p_target_type text,
    p_target_id uuid,
    p_target_name text DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_log_id uuid;
BEGIN
    INSERT INTO public.permission_audit_logs (
        actor_id, action, target_type, target_id, target_name, metadata
    ) VALUES (
        p_actor_id, p_action, p_target_type, p_target_id, p_target_name, p_metadata
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

-- ============================================
-- 5. TRIGGER: Auto-log role changes
-- ============================================
CREATE OR REPLACE FUNCTION public.audit_role_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM public.log_audit_event(
            (SELECT auth.uid()),
            'role.created',
            'role',
            NEW.id,
            NEW.name,
            jsonb_build_object('description', NEW.description)
        );
    ELSIF TG_OP = 'UPDATE' THEN
        PERFORM public.log_audit_event(
            (SELECT auth.uid()),
            'role.updated',
            'role',
            NEW.id,
            NEW.name,
            jsonb_build_object(
                'old_name', OLD.name,
                'new_name', NEW.name,
                'old_description', OLD.description,
                'new_description', NEW.description
            )
        );
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM public.log_audit_event(
            (SELECT auth.uid()),
            'role.deleted',
            'role',
            OLD.id,
            OLD.name,
            '{}'::jsonb
        );
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS audit_role_changes_trigger ON public.roles;
CREATE TRIGGER audit_role_changes_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.roles
    FOR EACH ROW EXECUTE FUNCTION public.audit_role_changes();

-- ============================================
-- 6. VIEW: User Permissions with Hierarchy
-- ============================================
CREATE OR REPLACE VIEW public.user_permissions_view AS
SELECT 
    p.id as profile_id,
    perm.code as permission_code,
    perm.category,
    COALESCE(rp.can_read, false) as can_read,
    COALESCE(rp.can_write, false) as can_write,
    COALESCE(rp.can_delete, false) as can_delete,
    r.name as role_name
FROM public.profiles p
LEFT JOIN public.roles r ON r.id = p.role_id
LEFT JOIN public.role_permissions rp ON rp.role_id = r.id
LEFT JOIN public.permissions perm ON perm.id = rp.permission_id
WHERE p.role_id IS NOT NULL;
