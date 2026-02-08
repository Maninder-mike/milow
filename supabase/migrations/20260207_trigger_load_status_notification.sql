-- Create a function to call the Edge Function
CREATE OR REPLACE FUNCTION public.handle_load_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Call Edge Function via pg_net (extension must be enabled)
    -- REPLACE 'PROJECT_REF' with your actual project reference ID
    -- Ensure you have the vault secret or use anon key if public (not recommended for email)
    -- This is a SCAFFOLD. Use Dashboard > Database > Webhooks for easier setup.
    
    -- perform net.http_post(
    --   url := 'https://vpvthgagvmjegdjcvlzp.supabase.co/functions/v1/on-load-status-change',
    --   body := json_build_object(
    --     'type', TG_OP,
    --     'table', TG_TABLE_NAME,
    --     'record', row_to_json(NEW),
    --     'old_record', row_to_json(OLD),
    --     'schema', TG_TABLE_SCHEMA
    --   )::jsonb
    -- );
    
    -- For now, just log to postgres logs to verify trigger fires
    RAISE LOG 'Load % status changed from % to %', NEW.id, OLD.status, NEW.status;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the Trigger
DROP TRIGGER IF EXISTS on_load_status_change ON public.loads;

CREATE TRIGGER on_load_status_change
AFTER UPDATE ON public.loads
FOR EACH ROW
EXECUTE FUNCTION public.handle_load_status_change();
