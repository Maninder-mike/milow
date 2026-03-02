-- Fix: Add missing columns to messages table
-- Purpose: Support load-scoped messaging and company-level RLS

-- 1. Add load_id if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'load_id') THEN
        ALTER TABLE public.messages ADD COLUMN load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 2. Add company_id if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'company_id') THEN
        ALTER TABLE public.messages ADD COLUMN company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 3. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_messages_load_id ON public.messages(load_id);
CREATE INDEX IF NOT EXISTS idx_messages_company_id ON public.messages(company_id);

-- 4. Enable Realtime (Safe check)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;
END $$;

-- 5. Update RLS Policies
DROP POLICY IF EXISTS "Users can view relevant messages" ON public.messages;
CREATE POLICY "Users can view relevant messages"
ON public.messages FOR SELECT
USING (
  auth.uid() = sender_id OR
  auth.uid() = receiver_id OR
  (load_id IS NOT NULL AND load_id IN (
    SELECT id FROM public.loads
    WHERE assigned_driver_id = auth.uid()
  )) OR
  (company_id IS NOT NULL AND company_id IN (
    SELECT company_id FROM public.profiles
    WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
  ))
);

DROP POLICY IF EXISTS "Users can send messages" ON public.messages;
CREATE POLICY "Users can send messages"
ON public.messages FOR INSERT
WITH CHECK (
  auth.uid() = sender_id AND (
    receiver_id IS NOT NULL OR
    (load_id IS NOT NULL AND load_id IN (
      SELECT id FROM public.loads
      WHERE assigned_driver_id = auth.uid()
    )) OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')
    )
  )
);
