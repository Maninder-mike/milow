-- Add expires_on column to quotes table
ALTER TABLE quotes 
ADD COLUMN IF NOT EXISTS expires_on TIMESTAMPTZ;
