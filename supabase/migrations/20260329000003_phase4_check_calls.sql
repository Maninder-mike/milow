-- Phase 4: Structured Check-Calls
-- Allows dispatchers to request specific data from drivers

-- 1. Create check_calls table
CREATE TABLE IF NOT EXISTS public.check_calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    load_id UUID NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    requester_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    
    type TEXT NOT NULL CHECK (type IN ('location', 'temperature', 'weight', 'eta', 'custom')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'expired')),
    
    prompt TEXT NOT NULL,
    options JSONB, -- For multiple choice or structured prompts
    
    response_data JSONB, -- The structured response from the driver
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ
);

-- 2. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE check_calls;

-- 3. RLS Policies
ALTER TABLE public.check_calls ENABLE ROW LEVEL SECURITY;

-- Dispatchers can see all check calls for their company
CREATE POLICY "Dispatchers can view company check_calls"
ON public.check_calls FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.company_id = check_calls.company_id
    AND profiles.role IN ('admin', 'dispatcher')
  )
);

CREATE POLICY "Dispatchers can create check_calls"
ON public.check_calls FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.company_id = check_calls.company_id
    AND profiles.role IN ('admin', 'dispatcher')
  )
);

-- Drivers can see check calls assigned to them
CREATE POLICY "Drivers can view assigned check_calls"
ON public.check_calls FOR SELECT
USING (driver_id = auth.uid());

-- Drivers can update their own check calls (to complete them)
CREATE POLICY "Drivers can respond to check_calls"
ON public.check_calls FOR UPDATE
USING (driver_id = auth.uid())
WITH CHECK (driver_id = auth.uid());

-- 4. Trigger to create load_event when check_call is responded to
CREATE OR REPLACE FUNCTION trg_check_call_updated()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'completed' AND OLD.status = 'pending') THEN
        INSERT INTO public.load_events (
            load_id,
            company_id,
            actor_id,
            event_type,
            event_data
        ) VALUES (
            NEW.load_id,
            NEW.company_id,
            NEW.driver_id,
            'check_call',
            jsonb_build_object(
                'check_call_id', NEW.id,
                'type', NEW.type,
                'prompt', NEW.prompt,
                'response', NEW.response_data
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_check_call_status_change
    AFTER UPDATE ON public.check_calls
    FOR EACH ROW
    EXECUTE FUNCTION trg_check_call_updated();
