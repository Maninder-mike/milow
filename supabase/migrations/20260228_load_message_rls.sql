-- Migration: 20260228_load_message_rls.sql
-- Purpose: Enable drivers to see and send messages for loads assigned to them

-- 1. Enable RLS on messages table (already enabled in base schema, but ensuring here)
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing restrictive policies if they conflict
-- Base schema had: auth.uid() = sender_id or auth.uid() = receiver_id
-- We want to expand this for load-scoped group chat.

DROP POLICY IF EXISTS "Users can view own messages" ON public.messages;

-- 3. Create expanded SELECT policy
CREATE POLICY "Users can view relevant messages"
ON public.messages FOR SELECT
USING (
  -- Direct messages
  auth.uid() = sender_id OR
  auth.uid() = receiver_id OR
  -- Load-scoped messages for assigned drivers
  (load_id IS NOT NULL AND load_id IN (
    SELECT id FROM public.loads
    WHERE assigned_driver_id = auth.uid()
  )) OR
  -- Company staff can see all company messages
  (company_id IS NOT NULL AND company_id IN (
    SELECT company_id FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
  ))
);

-- 4. Create expanded INSERT policy
DROP POLICY IF EXISTS "Users can send messages" ON public.messages;

CREATE POLICY "Users can send messages"
ON public.messages FOR INSERT
WITH CHECK (
  -- Sender must be the authenticated user
  auth.uid() = sender_id AND (
    -- Direct message
    receiver_id IS NOT NULL OR
    -- Load-scoped message for assigned driver
    (load_id IS NOT NULL AND load_id IN (
      SELECT id FROM public.loads
      WHERE assigned_driver_id = auth.uid()
    )) OR
    -- Dispatcher/Admin can send anywhere in company
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  )
);

-- 5. Comments
COMMENT ON POLICY "Users can view relevant messages" ON public.messages IS 'Allows direct message participants, assigned drivers for loads, and company staff to view messages.';
