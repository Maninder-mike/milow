-- =============================================================================
-- MIGRATION: Add pickup/delivery times and trip documents
-- Date: 2024-12-31
-- Purpose: Track pickup/delivery times and store trip-related documents (BOL/POD)
-- =============================================================================

-- 1. ADD PICKUP/DELIVERY TIMES TO TRIPS TABLE
-- These track the actual time the driver arrived/completed each stop
ALTER TABLE public.trips
ADD COLUMN IF NOT EXISTS pickup_times timestamptz[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS delivery_times timestamptz[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS pickup_completed boolean[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS delivery_completed boolean[] DEFAULT '{}';

COMMENT ON COLUMN trips.pickup_times IS 'Array of timestamps when each pickup was completed';
COMMENT ON COLUMN trips.delivery_times IS 'Array of timestamps when each delivery was completed';
COMMENT ON COLUMN trips.pickup_completed IS 'Array of booleans indicating if each pickup is completed';
COMMENT ON COLUMN trips.delivery_completed IS 'Array of booleans indicating if each delivery is completed';


-- 2. CREATE TRIP DOCUMENTS TABLE
-- Stores BOL (Bill of Lading) and POD (Proof of Delivery) documents
CREATE TABLE IF NOT EXISTS public.trip_documents (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    trip_id uuid REFERENCES public.trips(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) NOT NULL,
    company_id uuid REFERENCES public.companies(id),
    
    -- Document Info
    document_type text NOT NULL CHECK (document_type IN ('bol', 'pod', 'rate_confirmation', 'other')),
    file_path text NOT NULL,
    file_name text,
    file_size bigint,
    mime_type text,
    
    -- Location Reference (which pickup/delivery this document is for)
    stop_type text CHECK (stop_type IN ('pickup', 'delivery')),
    stop_index integer, -- Index in the pickup_locations or delivery_locations array
    
    -- Metadata
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.trip_documents ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_trip_documents_trip_id ON public.trip_documents(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_documents_user_id ON public.trip_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_documents_company_id ON public.trip_documents(company_id);
CREATE INDEX IF NOT EXISTS idx_trip_documents_document_type ON public.trip_documents(document_type);


-- 3. RLS POLICIES FOR TRIP DOCUMENTS

-- Users can view their own trip documents
DROP POLICY IF EXISTS "Users can view own trip documents" ON public.trip_documents;
CREATE POLICY "Users can view own trip documents"
  ON public.trip_documents FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can insert their own trip documents
DROP POLICY IF EXISTS "Users can insert own trip documents" ON public.trip_documents;
CREATE POLICY "Users can insert own trip documents"
  ON public.trip_documents FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own trip documents
DROP POLICY IF EXISTS "Users can update own trip documents" ON public.trip_documents;
CREATE POLICY "Users can update own trip documents"
  ON public.trip_documents FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can delete their own trip documents
DROP POLICY IF EXISTS "Users can delete own trip documents" ON public.trip_documents;
CREATE POLICY "Users can delete own trip documents"
  ON public.trip_documents FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- Company admins/dispatchers can view all company trip documents
DROP POLICY IF EXISTS "Company members can view trip documents" ON public.trip_documents;
CREATE POLICY "Company members can view trip documents"
  ON public.trip_documents FOR SELECT
  TO authenticated
  USING (
    company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
    OR auth.uid() = user_id
  );


-- 4. STORAGE BUCKET FOR TRIP DOCUMENTS
INSERT INTO storage.buckets (id, name, public)
VALUES ('trip_documents', 'trip_documents', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "Users can view own trip documents storage" ON storage.objects;
CREATE POLICY "Users can view own trip documents storage"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'trip_documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can upload trip documents storage" ON storage.objects;
CREATE POLICY "Users can upload trip documents storage"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'trip_documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

DROP POLICY IF EXISTS "Users can delete trip documents storage" ON storage.objects;
CREATE POLICY "Users can delete trip documents storage"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'trip_documents' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );


-- 5. TRIGGER TO SET COMPANY_ID ON INSERT
DROP TRIGGER IF EXISTS set_trip_document_company_id_trigger ON public.trip_documents;
CREATE TRIGGER set_trip_document_company_id_trigger
  BEFORE INSERT ON public.trip_documents
  FOR EACH ROW EXECUTE PROCEDURE public.set_company_id();
