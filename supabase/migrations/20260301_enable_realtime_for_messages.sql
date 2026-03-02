-- Enable Realtime for messages table
ALTER TABLE public.messages REPLICA IDENTITY FULL;

BEGIN;
  DROP PUBLICATION IF EXISTS supabase_realtime;
  CREATE PUBLICATION supabase_realtime FOR TABLE public.messages, public.announcements;
COMMIT;
