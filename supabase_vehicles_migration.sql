-- Rename tables from trucks to vehicles
ALTER TABLE public.trucks RENAME TO vehicles;
ALTER TABLE public.truck_documents RENAME TO vehicle_documents;

-- Rename columns
ALTER TABLE public.vehicles RENAME COLUMN truck_number TO vehicle_number;
ALTER TABLE public.vehicle_documents RENAME COLUMN truck_id TO vehicle_id;

-- Drop old triggers
DROP TRIGGER IF EXISTS set_truck_company_id_trigger ON public.vehicles;
DROP FUNCTION IF EXISTS public.set_truck_company_id();

DROP TRIGGER IF EXISTS set_truck_doc_company_id_trigger ON public.vehicle_documents;
DROP FUNCTION IF EXISTS public.set_truck_doc_company_id();

-- Create new trigger function for vehicles
CREATE OR REPLACE FUNCTION public.set_vehicle_company_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.company_id IS NULL THEN
    SELECT company_id INTO NEW.company_id FROM public.profiles WHERE id = auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger for vehicles
CREATE TRIGGER set_vehicle_company_id_trigger
BEFORE INSERT ON public.vehicles
FOR EACH ROW EXECUTE PROCEDURE public.set_vehicle_company_id();

-- Create new trigger function for vehicle_documents
CREATE OR REPLACE FUNCTION public.set_vehicle_doc_company_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.company_id IS NULL THEN
    SELECT company_id INTO NEW.company_id FROM public.profiles WHERE id = auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create new trigger for vehicle_documents
CREATE TRIGGER set_vehicle_doc_company_id_trigger
BEFORE INSERT ON public.vehicle_documents
FOR EACH ROW EXECUTE PROCEDURE public.set_vehicle_doc_company_id();

-- Drop old policies for trucks (now vehicles)
DROP POLICY IF EXISTS "Company members can view trucks" ON public.vehicles;
DROP POLICY IF EXISTS "Company members can insert trucks" ON public.vehicles;
DROP POLICY IF EXISTS "Company members can update trucks" ON public.vehicles;
DROP POLICY IF EXISTS "Company members can delete trucks" ON public.vehicles;

-- Create new policies for vehicles
CREATE POLICY "Company members can view vehicles"
ON public.vehicles FOR SELECT USING (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can insert vehicles"
ON public.vehicles FOR INSERT WITH CHECK (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can update vehicles"
ON public.vehicles FOR UPDATE USING (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can delete vehicles"
ON public.vehicles FOR DELETE USING (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

-- Drop old policies for truck_documents (now vehicle_documents)
DROP POLICY IF EXISTS "Company members can view truck documents" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Company members can insert truck documents" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Company members can update truck documents" ON public.vehicle_documents;
DROP POLICY IF EXISTS "Company members can delete truck documents" ON public.vehicle_documents;

-- Create new policies for vehicle_documents
CREATE POLICY "Company members can view vehicle documents"
ON public.vehicle_documents FOR SELECT USING (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can insert vehicle documents"
ON public.vehicle_documents FOR INSERT WITH CHECK (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can update vehicle documents"
ON public.vehicle_documents FOR UPDATE USING (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

CREATE POLICY "Company members can delete vehicle documents"
ON public.vehicle_documents FOR DELETE USING (
  company_id IN (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

-- Storage bucket updates
-- Try to rename the bucket if possible, otherwise we might need to create a new one.
-- Updating storage.buckets is usually the way to "rename"
-- Storage bucket updates
-- Create new bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('vehicle_documents', 'vehicle_documents', false)
ON CONFLICT (id) DO NOTHING;

-- Move objects to new bucket
UPDATE storage.objects
SET bucket_id = 'vehicle_documents'
WHERE bucket_id = 'truck_documents';

-- Drop old bucket
DELETE FROM storage.buckets WHERE id = 'truck_documents';

-- Drop old storage policies
DROP POLICY IF EXISTS "Company members can view truck documents storage" ON storage.objects;
DROP POLICY IF EXISTS "Company members can upload truck documents storage" ON storage.objects;
DROP POLICY IF EXISTS "Company members can delete truck documents storage" ON storage.objects;

-- Create new storage policies for vehicle_documents
CREATE POLICY "Company members can view vehicle documents storage"
  ON storage.objects FOR SELECT USING (
    bucket_id = 'vehicle_documents' AND
    (storage.foldername(name))[1] IN (
       SELECT company_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Company members can upload vehicle documents storage"
  ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'vehicle_documents' AND
    (storage.foldername(name))[1] IN (
       SELECT company_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Company members can delete vehicle documents storage"
  ON storage.objects FOR DELETE USING (
    bucket_id = 'vehicle_documents' AND
    (storage.foldername(name))[1] IN (
       SELECT company_id::text FROM public.profiles WHERE id = auth.uid()
    )
  );
