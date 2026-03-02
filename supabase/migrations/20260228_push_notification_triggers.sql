-- Migration: 20260228_push_notification_triggers.sql
-- Purpose: Add triggers to call Edge Functions for Push Notifications

-- 1. Trigger for New Messages
CREATE OR REPLACE FUNCTION public.handle_message_inserted()
RETURNS TRIGGER AS $$
BEGIN
  -- Call the on-message-created Edge Function
  -- Note: In production, use the service role key or a vault secret
  PERFORM net.http_post(
    url := 'https://vpvthgagvmjegdjcvlzp.supabase.co/functions/v1/on-message-created',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := json_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', row_to_json(NEW),
      'schema', TG_TABLE_SCHEMA
    )::jsonb
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_inserted_push ON public.messages;
CREATE TRIGGER on_message_inserted_push
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_message_inserted();


-- 2. Trigger for Load Assignment
CREATE OR REPLACE FUNCTION public.handle_load_assigned()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if assigned_driver_id changed from null to a value
  IF OLD.assigned_driver_id IS NULL AND NEW.assigned_driver_id IS NOT NULL THEN
    PERFORM net.http_post(
      url := 'https://vpvthgagvmjegdjcvlzp.supabase.co/functions/v1/on-load-assigned',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body := json_build_object(
        'type', TG_OP,
        'table', TG_TABLE_NAME,
        'record', row_to_json(NEW),
        'old_record', row_to_json(OLD),
        'schema', TG_TABLE_SCHEMA
      )::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_load_assigned_push ON public.loads;
CREATE TRIGGER on_load_assigned_push
AFTER UPDATE ON public.loads
FOR EACH ROW
EXECUTE FUNCTION public.handle_load_assigned();


-- 3. Update Load Status Change Trigger to use net.http_post (replacing log-only scaffold)
CREATE OR REPLACE FUNCTION public.handle_load_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    PERFORM net.http_post(
      url := 'https://vpvthgagvmjegdjcvlzp.supabase.co/functions/v1/on-load-status-change',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
      ),
      body := json_build_object(
        'type', TG_OP,
        'table', TG_TABLE_NAME,
        'record', row_to_json(NEW),
        'old_record', row_to_json(OLD),
        'schema', TG_TABLE_SCHEMA
      )::jsonb
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
