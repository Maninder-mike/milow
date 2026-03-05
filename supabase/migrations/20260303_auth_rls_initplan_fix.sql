-- Migration: 20260303_comprehensive_rls_initplan_fix.sql
-- Purpose: Wrap all remaining auth.uid() calls in (select auth.uid()) to fix auth_rls_initplan warnings.

-- Source: 20260302_crashlytics_fixes.sql
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles 
  FOR INSERT TO authenticated 
  WITH CHECK ((select auth.uid()) = id);

-- Source: 20260109_fix_profile_creation.sql
DROP POLICY IF EXISTS "Drivers can insert own profile" ON public.driver_profiles;
create policy "Drivers can insert own profile" on public.driver_profiles
    for insert to authenticated with check ((select auth.uid()) = id);

-- Source: 20260109_fix_profile_creation.sql
DROP POLICY IF EXISTS "Staff can insert own profile" ON public.company_staff_profiles;
create policy "Staff can insert own profile" on public.company_staff_profiles
    for insert to authenticated with check ((select auth.uid()) = id);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can view maintenance records for their org vehicles" ON maintenance_records;
CREATE POLICY "Users can view maintenance records for their org vehicles"
ON maintenance_records FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_records.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = (select auth.uid()))
  )
);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can create maintenance records for their org vehicles" ON maintenance_records;
CREATE POLICY "Users can create maintenance records for their org vehicles"
ON maintenance_records FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_records.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = (select auth.uid()))
  )
);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can update their own maintenance records" ON maintenance_records;
CREATE POLICY "Users can update their own maintenance records"
ON maintenance_records FOR UPDATE
USING (created_by = (select auth.uid()));

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can delete their own maintenance records" ON maintenance_records;
CREATE POLICY "Users can delete their own maintenance records"
ON maintenance_records FOR DELETE
USING (created_by = (select auth.uid()));

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can view maintenance schedules for their org vehicles" ON maintenance_schedules;
CREATE POLICY "Users can view maintenance schedules for their org vehicles"
ON maintenance_schedules FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_schedules.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = (select auth.uid()))
  )
);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can manage maintenance schedules for their org vehicles" ON maintenance_schedules;
CREATE POLICY "Users can manage maintenance schedules for their org vehicles"
ON maintenance_schedules FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = maintenance_schedules.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = (select auth.uid()))
  )
);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can view DVIR reports for their org vehicles" ON dvir_reports;
CREATE POLICY "Users can view DVIR reports for their org vehicles"
ON dvir_reports FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = dvir_reports.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = (select auth.uid()))
  )
);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can create DVIR reports for their org vehicles" ON dvir_reports;
CREATE POLICY "Users can create DVIR reports for their org vehicles"
ON dvir_reports FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM vehicles v
    WHERE v.id = dvir_reports.vehicle_id
    AND v.company_id = (SELECT company_id FROM profiles WHERE id = (select auth.uid()))
  )
);

-- Source: 20260124_maintenance_scheduling.sql
DROP POLICY IF EXISTS "Users can update DVIR reports they created or for correction" ON dvir_reports;
CREATE POLICY "Users can update DVIR reports they created or for correction"
ON dvir_reports FOR UPDATE
USING (
  driver_id = (select auth.uid()) OR 
  EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = (select auth.uid()) AND p.role IN ('admin', 'dispatcher', 'mechanic')
  )
);

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Users can read company and own boards" ON public.dashboard_boards;
CREATE POLICY "Users can read company and own boards"
ON public.dashboard_boards FOR SELECT
USING (
  (user_id IS NULL AND company_id = get_my_company_id())
  OR user_id = (select auth.uid())
);

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Users can manage own boards" ON public.dashboard_boards;
CREATE POLICY "Users can manage own boards"
ON public.dashboard_boards FOR ALL
USING (user_id = (select auth.uid()));

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Users can read widgets on accessible boards" ON public.dashboard_widgets;
CREATE POLICY "Users can read widgets on accessible boards"
ON public.dashboard_widgets FOR SELECT
USING (board_id IN (
  SELECT id FROM public.dashboard_boards WHERE 
    user_id = (select auth.uid()) 
    OR (user_id IS NULL AND company_id = get_my_company_id())
));

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Users can manage widgets on own boards" ON public.dashboard_widgets;
CREATE POLICY "Users can manage widgets on own boards"
ON public.dashboard_widgets FOR ALL
USING (board_id IN (SELECT id FROM public.dashboard_boards WHERE user_id = (select auth.uid())));

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Users can read own and shared views" ON public.saved_views;
CREATE POLICY "Users can read own and shared views"
ON public.saved_views FOR SELECT
USING (
  user_id = (select auth.uid())
  OR (is_shared = true AND company_id = get_my_company_id())
);

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Users can manage own views" ON public.saved_views;
CREATE POLICY "Users can manage own views"
ON public.saved_views FOR ALL
USING (user_id = (select auth.uid()));

-- Source: 20260207_roserocket_parity.sql
DROP POLICY IF EXISTS "Drivers can update assigned tasks" ON public.tasks;
CREATE POLICY "Drivers can update assigned tasks"
ON public.tasks FOR UPDATE
USING (assigned_driver_id = (select auth.uid()))
WITH CHECK (assigned_driver_id = (select auth.uid()));

-- Source: 20260302_crashlytics_fixes.sql
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles 
  FOR UPDATE TO authenticated 
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);

-- Source: 20260217_fix_profile_updates.sql
DROP POLICY IF EXISTS "Drivers can update own profile" ON public.driver_profiles;
create policy "Drivers can update own profile" on public.driver_profiles
    for update to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);

-- Source: 20260219_fix_settlement_rls_policies.sql
DROP POLICY IF EXISTS "Drivers can view their own pay configs" ON public.driver_pay_configs;
CREATE POLICY "Drivers can view their own pay configs" ON public.driver_pay_configs
  FOR SELECT
  USING (driver_id = (select auth.uid()));

-- Source: 20260219_fix_settlement_rls_policies.sql
DROP POLICY IF EXISTS "Drivers can view their own settlements" ON public.driver_settlements;
CREATE POLICY "Drivers can view their own settlements" ON public.driver_settlements
  FOR SELECT
  USING (driver_id = (select auth.uid()));

-- Source: 20260219_fix_settlement_rls_policies.sql
DROP POLICY IF EXISTS "Drivers can view their own settlement items" ON public.settlement_items;
CREATE POLICY "Drivers can view their own settlement items" ON public.settlement_items
  FOR SELECT
  USING (
    settlement_id IN (
      SELECT id FROM public.driver_settlements WHERE driver_id = (select auth.uid())
    )
  );

-- Source: 20260220_create_audit_logs.sql
DROP POLICY IF EXISTS "Users can insert audit logs" ON public.audit_logs;
create policy "Users can insert audit logs"
    on public.audit_logs
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);

-- Source: 20260220_create_audit_logs.sql
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
create policy "Admins can view audit logs"
    on public.audit_logs
    for select
    to authenticated
    using (
        exists (
            select 1 from public.profiles
            where profiles.id = (select auth.uid())
            and profiles.role = 'admin'
        )
    );

-- Source: 20260221_finalize_rls_policies.sql
DROP POLICY IF EXISTS "Strict message read access" ON public.messages;
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
                    WHERE assigned_driver_id = (select auth.uid())
                )
            )
        )
    )
);

-- Source: 20260221_finalize_rls_policies.sql
DROP POLICY IF EXISTS "Strict message insert access" ON public.messages;
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
                    WHERE assigned_driver_id = (select auth.uid())
                )
            )
        )
    )
);

-- Source: 20260221_finalize_rls_policies.sql
DROP POLICY IF EXISTS "Strict document review access" ON public.document_reviews;
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
                WHERE driver_id = (select auth.uid())
                -- OR created_by = (select auth.uid()) -- Optional safety net if columns exist
            )
        )
    )
);

-- Source: 20260221_messaging_docs_workflow.sql
DROP POLICY IF EXISTS "Dispatchers can create document reviews" ON public.document_reviews;
CREATE POLICY "Dispatchers can create document reviews"
ON public.document_reviews FOR INSERT
WITH CHECK (
    company_id = get_my_company_id() 
    AND (SELECT role FROM public.profiles WHERE id = (select auth.uid())) IN ('admin', 'dispatcher')
);

-- Source: 20260221_messaging_docs_workflow.sql
DROP POLICY IF EXISTS "Drivers can read messages for their loads" ON public.messages;
CREATE POLICY "Drivers can read messages for their loads"
ON public.messages FOR SELECT
USING (
    load_id IN (
        SELECT load_id FROM public.load_assignments 
        WHERE driver_id = (select auth.uid())
    )
);

-- Source: 20260301_fix_messages_table_columns.sql
DROP POLICY IF EXISTS "Users can view relevant messages" ON public.messages;
CREATE POLICY "Users can view relevant messages"
ON public.messages FOR SELECT
USING (
  (select auth.uid()) = sender_id OR
  (select auth.uid()) = receiver_id OR
  (load_id IS NOT NULL AND load_id IN (
    SELECT id FROM public.loads
    WHERE assigned_driver_id = (select auth.uid())
  )) OR
  (company_id IS NOT NULL AND company_id IN (
    SELECT company_id FROM public.profiles
    WHERE id = (select auth.uid()) AND role IN ('admin', 'dispatcher')
  ))
);

-- Source: 20260301_fix_messages_table_columns.sql
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
CREATE POLICY "Users can send messages"
ON public.messages FOR INSERT
WITH CHECK (
  (select auth.uid()) = sender_id AND (
    receiver_id IS NOT NULL OR
    (load_id IS NOT NULL AND load_id IN (
      SELECT id FROM public.loads
      WHERE assigned_driver_id = (select auth.uid())
    )) OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (select auth.uid()) AND role IN ('admin', 'dispatcher')
    )
  )
);

-- Source: 20260301_add_company_id_to_announcements.sql
DROP POLICY IF EXISTS "Users can view announcements for their company" ON public.announcements;
CREATE POLICY "Users can view announcements for their company" 
ON public.announcements FOR SELECT 
USING (
  company_id = (SELECT company_id FROM public.profiles WHERE id = (select auth.uid()))
);

-- Source: 20260301_add_company_id_to_announcements.sql
DROP POLICY IF EXISTS "Admins can create announcements" ON public.announcements;
CREATE POLICY "Admins can create announcements" 
ON public.announcements FOR INSERT 
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = (select auth.uid())) = 'admin'
);

-- Source: 20260301_add_delete_policy_to_announcements.sql
DROP POLICY IF EXISTS "Admins can delete announcements" ON public.announcements;
CREATE POLICY "Admins can delete announcements" 
ON public.announcements FOR DELETE 
TO authenticated
USING (
  (SELECT role FROM public.profiles WHERE id = (select auth.uid())) = 'admin'
);

-- Source: 20260302_critical_rls_fixes.sql
DROP POLICY IF EXISTS "Users can view own trips" ON public.driver_trips;
CREATE POLICY "Users can view own trips" ON public.driver_trips 
  FOR SELECT TO authenticated 
  USING (
    (select auth.uid()) = user_id OR 
    (company_id IS NOT NULL AND company_id IN (
        SELECT company_id FROM public.profiles WHERE id = (select auth.uid())
    ))
  );

-- Source: 20260302_critical_rls_fixes.sql
DROP POLICY IF EXISTS "Users can view own fuel entries" ON public.fuel_entries;
CREATE POLICY "Users can view own fuel entries" ON public.fuel_entries 
  FOR SELECT TO authenticated 
  USING (
    (select auth.uid()) = user_id OR 
    (company_id IS NOT NULL AND company_id IN (
        SELECT company_id FROM public.profiles WHERE id = (select auth.uid())
    ))
  );

-- Source: 20260302_critical_rls_fixes.sql
DROP POLICY IF EXISTS "Company members can view loads" ON public.loads;
CREATE POLICY "Company members can view loads" ON public.loads
  FOR SELECT TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = (select auth.uid()))
  );

-- Source: 20260302_critical_rls_fixes.sql
DROP POLICY IF EXISTS "Dispatchers can insert loads" ON public.loads;
CREATE POLICY "Dispatchers can insert loads" ON public.loads
  FOR INSERT TO authenticated
  WITH CHECK (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = (select auth.uid()))
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = (select auth.uid()) AND role IN ('admin', 'dispatcher', 'superadmin', 'owner')
    )
  );

-- Source: 20260302_critical_rls_fixes.sql
DROP POLICY IF EXISTS "Users can update loads" ON public.loads;
CREATE POLICY "Users can update loads" ON public.loads
  FOR UPDATE TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = (select auth.uid()))
    AND (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = (select auth.uid()) AND role IN ('admin', 'dispatcher', 'superadmin', 'owner')
        )
        OR (select auth.uid()) = assigned_driver_id
    )
  );

-- Source: 20260302_critical_rls_fixes.sql
DROP POLICY IF EXISTS "Dispatchers can delete loads" ON public.loads;
CREATE POLICY "Dispatchers can delete loads" ON public.loads
  FOR DELETE TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = (select auth.uid()))
    AND EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = (select auth.uid()) AND role IN ('admin', 'dispatcher', 'superadmin', 'owner')
    )
  );

