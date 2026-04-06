-- Phase 3: Document Exchange Pipeline
-- Adds load and stop association to documents table and enables event triggers

-- =============================================================
-- Step 1: Add load and stop foreign keys 
-- =============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'load_id') THEN
        ALTER TABLE public.documents ADD COLUMN load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'stop_id') THEN
        ALTER TABLE public.documents ADD COLUMN stop_id uuid REFERENCES public.stops(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'file_name') THEN
        ALTER TABLE public.documents ADD COLUMN file_name text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'file_path') THEN
        ALTER TABLE public.documents ADD COLUMN file_path text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'mime_type') THEN
        ALTER TABLE public.documents ADD COLUMN mime_type text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'file_size') THEN
        ALTER TABLE public.documents ADD COLUMN file_size bigint;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'documents' AND column_name = 'company_id') THEN
        ALTER TABLE public.documents ADD COLUMN company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_documents_load_id ON public.documents(load_id);
CREATE INDEX IF NOT EXISTS idx_documents_stop_id ON public.documents(stop_id);
CREATE INDEX IF NOT EXISTS idx_documents_company_id ON public.documents(company_id);

-- =============================================================
-- Step 2: RLS Policies for mobile driver uploads
-- =============================================================
-- Allow drivers to read their own load's documents
CREATE POLICY "Drivers can read documents for assigned loads"
ON public.documents FOR SELECT
USING (
    driver_id = auth.uid() OR
    (load_id IS NOT NULL AND
     EXISTS (
        SELECT 1 FROM public.loads
        WHERE id = load_id AND assigned_driver_id = auth.uid()
    ))
);

-- Allow drivers to upload documents to assigned loads
CREATE POLICY "Drivers can upload documents to their assigned loads"
ON public.documents FOR INSERT
WITH CHECK (
    load_id IS NOT NULL AND
    EXISTS (
        SELECT 1 FROM public.loads
        WHERE id = load_id AND assigned_driver_id = auth.uid()
    )
);

-- Allow drivers to update their own documents
CREATE POLICY "Drivers can update their own documents"
ON public.documents FOR UPDATE
USING (driver_id = auth.uid());

-- Allow dispatchers to view and update documents in their company
CREATE POLICY "Company dispatchers can manage documents"
ON public.documents FOR ALL
USING (
    company_id = get_my_company_id() 
    AND (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'dispatcher')))
);

-- =============================================================
-- Step 3: Trigger load_event on document upload
-- =============================================================
CREATE OR REPLACE FUNCTION public.notify_document_uploaded()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.load_id IS NOT NULL THEN
        INSERT INTO public.load_events (
            load_id,
            company_id,
            event_type,
            details,
            created_by
        ) VALUES (
            NEW.load_id,
            NEW.company_id,
            'document_uploaded',
            jsonb_build_object(
                'document_id', NEW.id,
                'document_type', NEW.document_type,
                'status', NEW.status,
                'file_name', NEW.file_name
            ),
            auth.uid()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_document_uploaded ON public.documents;
CREATE TRIGGER trg_document_uploaded
    AFTER INSERT ON public.documents
    FOR EACH ROW
    EXECUTE FUNCTION public.notify_document_uploaded();
