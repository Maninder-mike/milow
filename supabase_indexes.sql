-- Indexes for foreign keys to improve query performance
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_id ON public.messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);

-- Index for common filter
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
