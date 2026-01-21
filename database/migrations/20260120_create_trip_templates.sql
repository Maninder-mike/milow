-- =============================================================================
-- MIGRATION: Trip Templates
-- Date: 2026-01-20
-- Purpose: Allow users to save trips as templates for quick reuse
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.trip_templates (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    description text,
    
    -- Template Data (Stored as JSON to flexible schema changes)
    -- We store the entire trip structure here
    template_data jsonb NOT NULL,
    
    is_favorite boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- RLS Policies
ALTER TABLE public.trip_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own templates"
    ON public.trip_templates FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own templates"
    ON public.trip_templates FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own templates"
    ON public.trip_templates FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own templates"
    ON public.trip_templates FOR DELETE
    USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trip_templates_user_id ON public.trip_templates(user_id);
