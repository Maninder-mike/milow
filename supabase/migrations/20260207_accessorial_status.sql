-- Partial Gap Feature: Financial Line Item History
-- Adds status and audit tracking to accessorial_charges table

-- Step 1: Create enum type for charge status
DO $$ BEGIN
    CREATE TYPE charge_status AS ENUM (
        'pending',
        'approved', 
        'invoiced',
        'paid',
        'disputed',
        'rejected'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Step 2: Add new columns to accessorial_charges
ALTER TABLE public.accessorial_charges
ADD COLUMN IF NOT EXISTS status charge_status DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS approved_by uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS approved_at timestamptz;

-- Step 3: Create index for status filtering
CREATE INDEX IF NOT EXISTS idx_accessorial_charges_status 
ON public.accessorial_charges(status);

-- Step 4: Create index for audit queries
CREATE INDEX IF NOT EXISTS idx_accessorial_charges_created_by 
ON public.accessorial_charges(created_by);

-- Comment on columns for documentation
COMMENT ON COLUMN public.accessorial_charges.status IS 'Workflow status: pending → approved → invoiced → paid';
COMMENT ON COLUMN public.accessorial_charges.created_by IS 'User who created this accessorial charge';
COMMENT ON COLUMN public.accessorial_charges.approved_by IS 'User who approved this charge';
COMMENT ON COLUMN public.accessorial_charges.approved_at IS 'Timestamp when charge was approved';
