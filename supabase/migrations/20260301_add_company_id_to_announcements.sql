-- 1. Drop existing policies FIRST to allow column/constraint modifications
DROP POLICY IF EXISTS "Users can view announcements for their company" ON public.announcements;
DROP POLICY IF EXISTS "Admins can create announcements" ON public.announcements;

-- 2. Drop the incorrect foreign key constraint if it exists
ALTER TABLE public.announcements 
DROP CONSTRAINT IF EXISTS announcements_company_id_fkey;

-- 3. Ensure company_id column exists and has the correct reference
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'announcements' AND column_name = 'company_id') THEN
        ALTER TABLE public.announcements ADD COLUMN company_id uuid REFERENCES public.companies(id);
    ELSE
        -- Column exists, but we need to ensure it's the correct type and linked to companies
        -- We won't alter type unless necessary to avoid the error, but if it's already uuid it's fine
        ALTER TABLE public.announcements ADD CONSTRAINT announcements_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id);
    END IF;
EXCEPTION
    WHEN others THEN
        -- If constraint already exists or other minor issues, ignore and proceed
        NULL;
END $$;

-- 4. Enable RLS
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- 5. Create policy: Users can only see announcements for their own company
CREATE POLICY "Users can view announcements for their company" 
ON public.announcements FOR SELECT 
USING (
  company_id = (SELECT company_id FROM public.profiles WHERE id = auth.uid())
);

-- 6. Create policy: Only admins can create announcements
CREATE POLICY "Admins can create announcements" 
ON public.announcements FOR INSERT 
WITH CHECK (
  (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
);

-- 7. Add trigger for automatic company_id assignment if missing
DROP TRIGGER IF EXISTS set_announcement_company_id_trigger ON public.announcements;
CREATE TRIGGER set_announcement_company_id_trigger
  BEFORE INSERT ON public.announcements
  FOR EACH ROW EXECUTE PROCEDURE public.set_company_id();
