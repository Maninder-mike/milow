-- Enhancing Documents Feature (RoseRocket Parity)
-- Adds document types and links to multiple objects (Partner, Asset, Customer)

-- =============================================================
-- Step 1: Create document_type enum
-- =============================================================
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type') THEN
    CREATE TYPE document_type AS ENUM (
      'other',
      'contract',           -- Carrier/Customer contracts
      'rate_confirmation',  -- Load specific
      'bill_of_lading',     -- BOL
      'proof_of_delivery',  -- POD
      'invoice',            -- Financial
      'receipt',            -- Expenses/Fuel
      'insurance',          -- Compliance
      'authority',          -- FMCSA
      'w9',                 -- Tax
      'certificate',        -- Training/Safety
      'inspection',         -- Vehicle inspection
      'photo',              -- General photo
      'citation'            -- Ticket/Violation
    );
  END IF;
END $$;

-- =============================================================
-- Step 2: Update documents table structure
-- =============================================================

-- Add document_type column (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'document_type') THEN
        ALTER TABLE public.documents ADD COLUMN document_type document_type DEFAULT 'other';
    END IF;
END $$;

-- Add associations to other objects (polymorphic-like linking)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'customer_id') THEN
        ALTER TABLE public.documents ADD COLUMN customer_id uuid REFERENCES public.customers(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'vehicle_id') THEN
        ALTER TABLE public.documents ADD COLUMN vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'driver_id') THEN
        ALTER TABLE public.documents ADD COLUMN driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE CASCADE;
    END IF;
END $$;
-- NOTE: partner_id will be added when Partners table is created

-- Add compliance fields
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'expiration_date') THEN
        ALTER TABLE public.documents ADD COLUMN expiration_date date; -- For insurance/license
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'effective_date') THEN
        ALTER TABLE public.documents ADD COLUMN effective_date date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'reference_number') THEN
        ALTER TABLE public.documents ADD COLUMN reference_number text; -- Policy #, Invoice #
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'tags') THEN
        ALTER TABLE public.documents ADD COLUMN tags text[] DEFAULT '{}';
    END IF;
END $$;

-- =============================================================
-- Step 3: Create indexes for new columns
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_documents_type ON public.documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_customer ON public.documents(customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_documents_vehicle ON public.documents(vehicle_id) WHERE vehicle_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_documents_driver ON public.documents(driver_id) WHERE driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_documents_expiration ON public.documents(expiration_date) WHERE expiration_date IS NOT NULL;

-- =============================================================
-- Step 4: Comments
-- =============================================================
COMMENT ON COLUMN public.documents.document_type IS 'Classification (POD, BOL, Contract) for automation';
COMMENT ON COLUMN public.documents.expiration_date IS 'For compliance docs like insurance & licenses';
