-- Create load_events table
CREATE TABLE IF NOT EXISTS public.load_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  load_id UUID REFERENCES public.loads(id) ON DELETE CASCADE NOT NULL,
  company_id UUID REFERENCES public.companies(id) NOT NULL,
  actor_id UUID REFERENCES auth.users(id) DEFAULT auth.uid() NOT NULL,
  event_type TEXT NOT NULL,
  event_data JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.load_events ENABLE ROW LEVEL SECURITY;

-- Add RLS Policies
CREATE POLICY "Company members can read load events"
ON public.load_events FOR SELECT
USING (
  company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can insert load events"
ON public.load_events FOR INSERT
WITH CHECK (
  company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

-- Trigger to auto-set company_id if not provided
DROP TRIGGER IF EXISTS set_load_events_company_id_trigger ON public.load_events;
CREATE TRIGGER set_load_events_company_id_trigger
  BEFORE INSERT ON public.load_events
  FOR EACH ROW EXECUTE PROCEDURE public.set_company_id();

-- Realtime Configuration
-- We need to make sure the realtime publication includes this table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'load_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.load_events;
  END IF;
END $$;
