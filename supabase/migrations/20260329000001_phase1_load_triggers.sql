-- Create trigger function to track load changes
CREATE OR REPLACE FUNCTION public.notify_load_change() RETURNS TRIGGER AS $$
BEGIN
  -- Track assignment changes
  IF OLD.assigned_driver_id IS DISTINCT FROM NEW.assigned_driver_id AND NEW.assigned_driver_id IS NOT NULL THEN
    INSERT INTO public.load_events (load_id, company_id, actor_id, event_type, event_data)
    VALUES (
      NEW.id, 
      NEW.company_id, 
      coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), -- Fallback for system updates
      'assigned', 
      jsonb_build_object('driver_id', NEW.assigned_driver_id)
    );
  END IF;

  -- Track status changes
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    DECLARE
       ev_type TEXT := 'status_changed';
    BEGIN
       IF NEW.status = 'accepted' THEN ev_type := 'accepted'; END IF;
       IF NEW.status = 'rejected' THEN ev_type := 'rejected'; END IF;
       IF NEW.status = 'en_route' THEN ev_type := 'enRoute'; END IF;
       
       INSERT INTO public.load_events (load_id, company_id, actor_id, event_type, event_data)
       VALUES (
         NEW.id, 
         NEW.company_id, 
         coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 
         ev_type, 
         jsonb_build_object('old', OLD.status, 'new', NEW.status)
       );
    END;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add trigger to loads table
DROP TRIGGER IF EXISTS on_load_change ON public.loads;
CREATE TRIGGER on_load_change
AFTER UPDATE ON public.loads
FOR EACH ROW EXECUTE FUNCTION public.notify_load_change();

-- Create trigger function to track stop changes
CREATE OR REPLACE FUNCTION public.notify_stop_change() RETURNS TRIGGER AS $$
DECLARE
  v_company_id UUID;
BEGIN
  SELECT company_id INTO v_company_id FROM public.loads WHERE id = NEW.load_id;

  -- Track arrival
  IF OLD.arrived_at IS DISTINCT FROM NEW.arrived_at AND NEW.arrived_at IS NOT NULL THEN
    INSERT INTO public.load_events (load_id, company_id, actor_id, event_type, event_data)
    VALUES (
      NEW.load_id, 
      v_company_id, 
      coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 
      'arrived', 
      jsonb_build_object('stop_sequence', NEW.sequence)
    );
  END IF;

  -- Track completion
  IF OLD.is_completed IS DISTINCT FROM NEW.is_completed AND NEW.is_completed = true THEN
    INSERT INTO public.load_events (load_id, company_id, actor_id, event_type, event_data)
    VALUES (
      NEW.load_id, 
      v_company_id, 
      coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid), 
      'completed', 
      jsonb_build_object('stop_sequence', NEW.sequence)
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add trigger to stops table
DROP TRIGGER IF EXISTS on_stop_change ON public.stops;
CREATE TRIGGER on_stop_change
AFTER UPDATE ON public.stops
FOR EACH ROW EXECUTE FUNCTION public.notify_stop_change();
