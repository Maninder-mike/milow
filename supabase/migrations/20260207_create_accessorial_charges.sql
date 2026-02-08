-- Create Accessorial Charges Table
CREATE TABLE IF NOT EXISTS public.accessorial_charges (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE NOT NULL,
    type text NOT NULL, -- Detention, Lumper, Layover, Tarp, Scale, Other
    amount numeric NOT NULL DEFAULT 0,
    currency text NOT NULL DEFAULT 'CAD',
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- RLS Policies
ALTER TABLE public.accessorial_charges ENABLE ROW LEVEL SECURITY;

-- Allow all actions for authenticated users (same as other tables for now)
CREATE POLICY "Enable all access for authenticated users" 
ON public.accessorial_charges 
FOR ALL 
USING (auth.role() = 'authenticated');

-- Grants (ensure authenticated users can use the table)
GRANT ALL ON TABLE public.accessorial_charges TO authenticated;
GRANT ALL ON TABLE public.accessorial_charges TO service_role;
