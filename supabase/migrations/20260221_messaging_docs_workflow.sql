-- Phase 2: Messaging & Document Workflows
-- Enhances messages and documents tables to support load-scoped chat and formalized approvals

-- =============================================================
-- Step 1: Enhance messages table for load-scoped chat
-- =============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'load_id') THEN
        ALTER TABLE public.messages ADD COLUMN load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_messages_load_id ON public.messages(load_id);

-- =============================================================
-- Step 2: Formalize document approval workflow
-- =============================================================

-- Create document_status enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_status') THEN
    CREATE TYPE document_status AS ENUM ('pending', 'approved', 'rejected');
  END IF;
END $$;

-- Add status and review fields to documents table
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'status') THEN
        ALTER TABLE public.documents ADD COLUMN status document_status DEFAULT 'pending';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'review_notes') THEN
        ALTER TABLE public.documents ADD COLUMN review_notes text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'reviewed_by') THEN
        ALTER TABLE public.documents ADD COLUMN reviewed_by uuid REFERENCES public.profiles(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_documents_status ON public.documents(status);

-- =============================================================
-- Step 3: Create document_reviews table for audit trail
-- =============================================================
CREATE TABLE IF NOT EXISTS public.document_reviews (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    document_id uuid NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
    reviewer_id uuid NOT NULL REFERENCES public.profiles(id),
    
    old_status document_status,
    new_status document_status NOT NULL,
    notes text,
    
    created_at timestamptz DEFAULT now()
);

-- Indexes for reviews
CREATE INDEX IF NOT EXISTS idx_document_reviews_doc ON public.document_reviews(document_id);
CREATE INDEX IF NOT EXISTS idx_document_reviews_reviewer ON public.document_reviews(reviewer_id);

-- =============================================================
-- Step 4: Update RLS Policies
-- =============================================================

-- Ensure RLS is enabled
ALTER TABLE public.document_reviews ENABLE ROW LEVEL SECURITY;

-- Document Reviews Policies
CREATE POLICY "Company members can read document reviews"
ON public.document_reviews FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Dispatchers can create document reviews"
ON public.document_reviews FOR INSERT
WITH CHECK (
    company_id = get_my_company_id() 
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'dispatcher')
);

-- Update messages RLS to allow access by load_id if assigned
-- (Assuming an assignment check function or similar exists)
-- This is a placeholder for the logic - Adjust based on actual assignment table names
/*
CREATE POLICY "Drivers can read messages for their loads"
ON public.messages FOR SELECT
USING (
    load_id IN (
        SELECT load_id FROM public.load_assignments 
        WHERE driver_id = auth.uid()
    )
);
*/

-- =============================================================
-- Step 5: Comments
-- =============================================================
COMMENT ON COLUMN public.messages.load_id IS 'Associates a message with a specific load for contextual chat';
COMMENT ON COLUMN public.documents.status IS 'Current approval state of the document';
COMMENT ON COLUMN public.document_reviews.notes IS 'Dispatch notes during approval/rejection';
