-- Drop existing quote-related tables
DROP TABLE IF EXISTS public.quote_csrs CASCADE;
DROP TABLE IF EXISTS public.quote_tags CASCADE;
DROP TABLE IF EXISTS public.quotes CASCADE;

-- Create fresh quotes table
CREATE TABLE public.quotes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  load_id UUID REFERENCES public.loads(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'won', 'lost')),
  line_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  total NUMERIC(12,2) NOT NULL DEFAULT 0,
  notes TEXT DEFAULT '',
  expires_on TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_quotes_load_id ON public.quotes(load_id);
CREATE INDEX idx_quotes_status ON public.quotes(status);

-- Enable RLS
ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Authenticated users can read quotes" ON public.quotes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Authenticated users can insert quotes" ON public.quotes
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update quotes" ON public.quotes
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Authenticated users can delete quotes" ON public.quotes
  FOR DELETE TO authenticated USING (true);
