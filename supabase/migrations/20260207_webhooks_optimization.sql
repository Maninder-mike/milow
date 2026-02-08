-- Optimizing Webhooks Feature (RoseRocket Parity)
-- Implements namespaced events, status change detection, and rich payloads

-- =============================================================
-- Step 1: Enhance webhook_subscriptions
-- =============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_subscriptions' AND column_name = 'description') THEN
        ALTER TABLE public.webhook_subscriptions ADD COLUMN description text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhook_subscriptions' AND column_name = 'custom_headers') THEN
        ALTER TABLE public.webhook_subscriptions ADD COLUMN custom_headers jsonb DEFAULT '{}';
    END IF;
END $$;

-- =============================================================
-- Step 2: Update queue_webhook_event function
-- =============================================================

CREATE OR REPLACE FUNCTION queue_webhook_event()
RETURNS TRIGGER AS $$
DECLARE
  p_object_type text;
  v_event_type text;
  v_company_id uuid;
  v_payload jsonb;
  v_old_data jsonb;
  v_new_data jsonb;
  v_changes jsonb;
BEGIN
  -- Get object type from trigger arguments
  p_object_type := TG_ARGV[0];
  IF TG_OP = 'DELETE' THEN
    v_company_id := OLD.company_id;
    v_old_data := to_jsonb(OLD);
    v_new_data := NULL;
  ELSE
    v_company_id := NEW.company_id;
    v_old_data := CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE NULL END;
    v_new_data := to_jsonb(NEW);
  END IF;

  IF v_company_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Construct base event type (e.g., 'load.created')
  IF TG_OP = 'INSERT' THEN
    v_event_type := p_object_type || '.created';
  ELSIF TG_OP = 'UPDATE' THEN
    v_event_type := p_object_type || '.updated';
  ELSIF TG_OP = 'DELETE' THEN
    v_event_type := p_object_type || '.deleted';
  END IF;

  -- Construct payload with diff support
  v_payload := jsonb_build_object(
    'event_id', gen_random_uuid(), -- Trace ID
    'event_type', v_event_type,
    'object_type', p_object_type,
    'occurred_at', now(),
    'data', COALESCE(v_new_data, v_old_data)
  );

  IF TG_OP = 'UPDATE' THEN
    v_payload := v_payload || jsonb_build_object('previous_data', v_old_data);
  END IF;

  -- Queue the main CRUD event
  INSERT INTO public.webhook_events (
    company_id, event_type, object_type, object_id, payload
  ) VALUES (
    v_company_id, v_event_type, p_object_type,
    COALESCE(NEW.id, OLD.id),
    v_payload
  );

  -- SPECIAL HANDLING: Status Changes
  -- If the object has a 'status' column and it changed, emit a specific event
  IF TG_OP = 'UPDATE' AND (v_new_data ? 'status') AND (v_old_data ? 'status') THEN
    IF v_new_data->>'status' IS DISTINCT FROM v_old_data->>'status' THEN
      v_event_type := p_object_type || '.status_changed';
      
      -- Enriched payload for status change
      v_payload := v_payload || jsonb_build_object(
        'event_type', v_event_type,
        'status_from', v_old_data->>'status',
        'status_to', v_new_data->>'status'
      );

      INSERT INTO public.webhook_events (
        company_id, event_type, object_type, object_id, payload
      ) VALUES (
        v_company_id, v_event_type, p_object_type,
        COALESCE(NEW.id, OLD.id),
        v_payload
      );
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================
-- Step 3: Re-create triggers (optional, but good to be explicit naming)
-- =============================================================
-- Existing triggers calling queue_webhook_event('load') will now use the new logic automatically
-- because we replaced the function definition.

-- Ensure tasks have webhook trigger (from earlier migration, but for safety)
DROP TRIGGER IF EXISTS webhook_tasks ON public.tasks;
CREATE TRIGGER webhook_tasks
AFTER INSERT OR UPDATE OR DELETE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('task');

-- =============================================================
-- Step 4: Comments
-- =============================================================
COMMENT ON COLUMN public.webhook_subscriptions.custom_headers IS 'JSON object of headers to send (e.g. Authorization)';
COMMENT ON FUNCTION queue_webhook_event IS 'Generates namespaced events (e.g. load.created) and status change events';
