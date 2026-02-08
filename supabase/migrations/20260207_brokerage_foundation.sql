-- Brokerage Foundation (Partners & Manifests)
-- Implements core brokerage tables to allow assigning loads to external carriers

-- =============================================================
-- PART 1: PARTNERS (Carriers)
-- =============================================================

CREATE TABLE IF NOT EXISTS public.partners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Core Identification
  name text NOT NULL,
  mc_number text, -- Motor Carrier Number (FMCSA)
  dot_number text, -- USDOT Number
  scac text, -- Standard Carrier Alpha Code
  
  -- Status
  status text NOT NULL DEFAULT 'onboarding' CHECK (status IN ('onboarding', 'active', 'inactive', 'rejected')),
  
  -- Relationships
  address_id uuid REFERENCES public.addresses(id) ON DELETE SET NULL, -- Main HQ address
  primary_contact_id uuid REFERENCES public.contacts(id) ON DELETE SET NULL,
  
  -- Compliance
  insurance_expiration date,
  safety_rating text CHECK (safety_rating IN ('satisfactory', 'conditional', 'unsatisfactory', 'not_rated')),
  
  -- Metadata
  notes text,
  currency text DEFAULT 'USD' CHECK (currency IN ('USD', 'CAD')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_partners_company ON public.partners(company_id);
CREATE INDEX IF NOT EXISTS idx_partners_status ON public.partners(status);
CREATE INDEX IF NOT EXISTS idx_partners_mc ON public.partners(mc_number);

-- RLS
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Company members can read partners"
ON public.partners FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Company members can insert partners"
ON public.partners FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Company members can update partners"
ON public.partners FOR UPDATE
USING (company_id = get_my_company_id());

CREATE POLICY "Company members can delete partners"
ON public.partners FOR DELETE
USING (company_id = get_my_company_id());

-- Triggers
DROP TRIGGER IF EXISTS partners_updated_at ON public.partners;
CREATE TRIGGER partners_updated_at
BEFORE UPDATE ON public.partners
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Webhooks
DROP TRIGGER IF EXISTS webhook_partners ON public.partners;
CREATE TRIGGER webhook_partners
AFTER INSERT OR UPDATE OR DELETE ON public.partners
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event(); -- Uses improved hook

-- =============================================================
-- PART 2: MANIFESTS (Carrier Contracts)
-- =============================================================

CREATE TABLE IF NOT EXISTS public.manifests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Manifest ID (Human readable)
  manifest_number bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  -- Actually let's use a sequence manually or leave it for app to generate or simplified uuid for now.
  -- RoseRocket uses "M-1001". Let's stick to UUID + maybe a display ID later.
  
  -- Relationships
  partner_id uuid NOT NULL REFERENCES public.partners(id),
  
  -- Status
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'offered', 'assigned', 'in_transit', 'completed', 'void')),
  
  -- Financials
  agreed_cost numeric(10, 2) DEFAULT 0,
  currency text DEFAULT 'USD' CHECK (currency IN ('USD', 'CAD')),
  
  -- Scheduling
  scheduled_pickup timestamptz,
  scheduled_delivery timestamptz,
  
  -- Metadata
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_manifests_company ON public.manifests(company_id);
CREATE INDEX IF NOT EXISTS idx_manifests_partner ON public.manifests(partner_id);
CREATE INDEX IF NOT EXISTS idx_manifests_status ON public.manifests(status);

-- RLS
ALTER TABLE public.manifests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Company members can read manifests"
ON public.manifests FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Company members can insert manifests"
ON public.manifests FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Company members can update manifests"
ON public.manifests FOR UPDATE
USING (company_id = get_my_company_id());

CREATE POLICY "Company members can delete manifests"
ON public.manifests FOR DELETE
USING (company_id = get_my_company_id());

-- Triggers
DROP TRIGGER IF EXISTS manifests_updated_at ON public.manifests;
CREATE TRIGGER manifests_updated_at
BEFORE UPDATE ON public.manifests
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Webhooks
DROP TRIGGER IF EXISTS webhook_manifests ON public.manifests;
CREATE TRIGGER webhook_manifests
AFTER INSERT OR UPDATE OR DELETE ON public.manifests
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event();

-- =============================================================
-- PART 3: MANIFEST ITEMS (Link Loads to Manifests)
-- =============================================================

CREATE TABLE IF NOT EXISTS public.manifest_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  manifest_id uuid NOT NULL REFERENCES public.manifests(id) ON DELETE CASCADE,
  load_id uuid NOT NULL REFERENCES public.loads(id) ON DELETE CASCADE,
  
  -- Sorting
  sequence integer DEFAULT 0,
  
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(manifest_id, load_id) -- Prevent duplicate assignment to same manifest
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_manifest_items_manifest ON public.manifest_items(manifest_id);
CREATE INDEX IF NOT EXISTS idx_manifest_items_load ON public.manifest_items(load_id);

-- RLS
ALTER TABLE public.manifest_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Company members can read manifest items"
ON public.manifest_items FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Company members can insert manifest items"
ON public.manifest_items FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Company members can delete manifest items"
ON public.manifest_items FOR DELETE
USING (company_id = get_my_company_id());
