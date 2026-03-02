-- Migration adding company_id to notifications table
-- Matches the connectivity audit recommendation to ensure notifications are scoped

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id);

CREATE INDEX IF NOT EXISTS idx_notifications_company_id ON public.notifications(company_id);

-- Add helpful comments to the schema
COMMENT ON COLUMN public.notifications.company_id IS 'Company to which this notification belongs, for scoping and RLS';
