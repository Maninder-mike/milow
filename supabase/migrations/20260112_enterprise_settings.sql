-- Add Enterprise Settings columns to companies table

ALTER TABLE public.companies
ADD COLUMN IF NOT EXISTS hos_rule_set text DEFAULT 'US Federal 70/8',
ADD COLUMN IF NOT EXISTS max_governance_speed numeric DEFAULT 65.0,
ADD COLUMN IF NOT EXISTS enforce_2fa boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS password_rotation_days int DEFAULT 90,
ADD COLUMN IF NOT EXISTS dispatch_webhook_url text,
ADD COLUMN IF NOT EXISTS api_keys jsonb DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.companies.hos_rule_set IS 'Hours of Service rule set (e.g. US Federal 70/8, Canadian South 70/7)';
COMMENT ON COLUMN public.companies.max_governance_speed IS 'Maximum speed limit for fleet vehicles for governance monitoring';
COMMENT ON COLUMN public.companies.enforce_2fa IS 'Whether 2FA is enforced for all company users';
COMMENT ON COLUMN public.companies.password_rotation_days IS 'Number of days before password rotation is required';
COMMENT ON COLUMN public.companies.dispatch_webhook_url IS 'Webhook URL for dispatch events';
COMMENT ON COLUMN public.companies.api_keys IS 'List of API keys for external integrations';
