-- Migration: Add advanced pay configuration fields to driver_pay_configs

ALTER TABLE public.driver_pay_configs
ADD COLUMN IF NOT EXISTS empty_cpm numeric,
ADD COLUMN IF NOT EXISTS stop_off_pay numeric,
ADD COLUMN IF NOT EXISTS detention_pay_per_hour numeric,
ADD COLUMN IF NOT EXISTS layover_pay numeric,
ADD COLUMN IF NOT EXISTS recurring_deductions jsonb DEFAULT '[]'::jsonb;

-- Example format for recurring_deductions:
-- [
--   {"name": "Truck Insurance", "amount": 150.00, "frequency": "weekly"},
--   {"name": "Escrow", "amount": 50.00, "frequency": "per_settlement"}
-- ]
