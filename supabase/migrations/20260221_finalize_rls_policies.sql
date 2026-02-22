-- =============================================================================
-- MIGRATION: 20260221_finalize_rls_policies.sql
-- Purpose: Implement strict RLS for messages and document reviews
-- Scopes:
--   - Admins/Dispatchers: Company-wide access
--   - Drivers: Load-scoped message access and own document review access
-- =============================================================================

-- ###########################################################################
-- 1. MESSAGES RLS
-- ###########################################################################

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Company members can view messages" ON public.messages;
DROP POLICY IF EXISTS "Authenticated users can insert messages" ON public.messages;

-- Policy for viewing messages
-- Note: We use the helper get_my_company_id() and get_user_role()
CREATE POLICY "Strict message read access"
ON public.messages
FOR SELECT
TO authenticated
USING (
    company_id = get_my_company_id() 
    AND (
        -- Admins and Dispatchers see everything in the company
        get_user_role() IN ('admin', 'dispatcher', 'safetyOfficer')
        -- Drivers see:
        OR (
            get_user_role() = 'driver' 
            AND (
                -- 1. General company messages (no load context)
                load_id IS NULL
                -- 2. Messages for loads they are specifically assigned to
                OR load_id IN (
                    SELECT id FROM public.loads 
                    WHERE assigned_driver_id = auth.uid()
                )
            )
        )
    )
);

-- Policy for sending messages
CREATE POLICY "Strict message insert access"
ON public.messages
FOR INSERT
TO authenticated
WITH CHECK (
    company_id = get_my_company_id()
    AND (
        -- Admins/Dispatchers can send to any load in their company
        get_user_role() IN ('admin', 'dispatcher', 'safetyOfficer')
        -- Drivers can only send to loads they are assigned to (or general chat)
        OR (
            get_user_role() = 'driver'
            AND (
                load_id IS NULL 
                OR load_id IN (
                    SELECT id FROM public.loads 
                    WHERE assigned_driver_id = auth.uid()
                )
            )
        )
    )
);

-- ###########################################################################
-- 2. DOCUMENT REVIEWS RLS
-- ###########################################################################

-- Drop existing if any
DROP POLICY IF EXISTS "Company members can read document reviews" ON public.document_reviews;

CREATE POLICY "Strict document review access"
ON public.document_reviews
FOR SELECT
TO authenticated
USING (
    -- Shared company ID
    company_id = get_my_company_id()
    AND (
        -- Staff see all reviews
        get_user_role() IN ('admin', 'dispatcher', 'safetyOfficer')
        -- Drivers only see reviews for documents they are associated with
        OR (
            get_user_role() = 'driver'
            AND document_id IN (
                SELECT id FROM public.documents 
                WHERE driver_id = auth.uid()
                -- OR created_by = auth.uid() -- Optional safety net if columns exist
            )
        )
    )
);

-- ###########################################################################
-- 3. AUDIT LOGS (Finalizing for Phase 2)
-- ###########################################################################
-- Ensure audit logs are also company scoped
DROP POLICY IF EXISTS "Company members can view their audit logs" ON public.audit_logs;
CREATE POLICY "Company members can view their audit logs"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (company_id = get_my_company_id());

-- Comments
COMMENT ON POLICY "Strict message read access" ON public.messages IS 'Filters message visibility: Company-wide for staff, load-scoped for drivers.';
COMMENT ON POLICY "Strict document review access" ON public.document_reviews IS 'Restricts review visibility: Staff see all, drivers see their own docs.';
