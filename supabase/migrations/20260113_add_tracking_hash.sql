-- Migration: Add Tracking Hash to Loads

-- Add tracking_hash column to loads table
ALTER TABLE loads ADD COLUMN tracking_hash text;
CREATE UNIQUE INDEX idx_loads_tracking_hash ON loads(tracking_hash);

-- Automatically generate tracking_hash via trigger on load insertion
CREATE OR REPLACE FUNCTION generate_load_tracking_hash()
RETURNS TRIGGER AS $$
BEGIN
  -- Generate a short unique hash e.g. 'mlw_' + 8 hex chars
  IF NEW.tracking_hash IS NULL THEN
    NEW.tracking_hash := 'mlw_' || encode(gen_random_bytes(4), 'hex');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_tracking_hash
  BEFORE INSERT ON loads
  FOR EACH ROW
  EXECUTE FUNCTION generate_load_tracking_hash();

-- Create RLS policy: Public users can read a load IF they have the tracking hash
-- But we only want them to read specific fields, so we do this in an Edge Function instead of public RLS
-- to prevent full exposure. However, if we want to allow direct DB access, we can create a secure view.
-- For now, the Edge Function will use the service_role key to bypass RLS and return sanitized data.
