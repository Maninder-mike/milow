-- Migration adding Enterprise Settings to the companies table
-- Matches the Company Dart model drift identified in the connectivity audit

ALTER TABLE public.companies
    ADD COLUMN IF NOT EXISTS hos_rule_set text,
    ADD COLUMN IF NOT EXISTS max_governance_speed numeric,
    ADD COLUMN IF NOT EXISTS enforce_2fa boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS password_rotation_days integer DEFAULT 90,
    ADD COLUMN IF NOT EXISTS dispatch_webhook_url text,
    ADD COLUMN IF NOT EXISTS api_keys jsonb DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS dot_number text,
    ADD COLUMN IF NOT EXISTS mc_number text;

-- Add helpful comments to the schema
COMMENT ON COLUMN public.companies.hos_rule_set IS 'Hours of Service Rule Set (e.g. US 70/8, Canada South, etc.)';
COMMENT ON COLUMN public.companies.max_governance_speed IS 'Maximum speed limit for governance purposes (e.g. 65.0 mph)';
COMMENT ON COLUMN public.companies.enforce_2fa IS 'Whether Two-Factor Authentication is enforced for all company members';
COMMENT ON COLUMN public.companies.password_rotation_days IS 'Number of days before users must rotate passwords';
COMMENT ON COLUMN public.companies.dispatch_webhook_url IS 'External webhook URL to receive dispatch events';
COMMENT ON COLUMN public.companies.api_keys IS 'JSON array of generated API keys for the company';
COMMENT ON COLUMN public.companies.dot_number IS 'USDOT Number for the company';
COMMENT ON COLUMN public.companies.mc_number IS 'Motor Carrier Number for the company';
