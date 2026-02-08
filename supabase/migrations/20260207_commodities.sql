-- Implementing Commodities Feature (RoseRocket Parity)
-- Creates commodities table for detailed freight item tracking

-- =============================================================
-- Step 1: Create freight_class enum
-- =============================================================
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'freight_class') THEN
    CREATE TYPE freight_class AS ENUM (
      'class_50', 'class_55', 'class_60', 'class_65', 'class_70',
      'class_77_5', 'class_85', 'class_92_5', 'class_100', 'class_110',
      'class_125', 'class_150', 'class_175', 'class_200', 'class_250',
      'class_300', 'class_400', 'class_500'
    );
  END IF;
END $$;

-- =============================================================
-- Step 2: Create hazmat_packing_group enum
-- =============================================================
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'hazmat_packing_group') THEN
    CREATE TYPE hazmat_packing_group AS ENUM (
      'I',   -- High danger
      'II',  -- Medium danger
      'III'  -- Low danger
    );
  END IF;
END $$;

-- =============================================================
-- Step 3: Create temperature_requirement enum
-- =============================================================
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'temperature_requirement') THEN
    CREATE TYPE temperature_requirement AS ENUM (
      'none',
      'frozen',      -- Below 0°F / -18°C
      'refrigerated', -- 33-40°F / 1-4°C
      'cool',        -- 45-60°F / 7-15°C
      'heated'       -- Above 50°F / 10°C
    );
  END IF;
END $$;

-- =============================================================
-- Step 4: Create commodities table
-- =============================================================
CREATE TABLE IF NOT EXISTS public.commodities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Parent associations (can belong to load or stop)
  load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE,
  stop_id uuid REFERENCES public.stops(id) ON DELETE CASCADE,
  
  -- Basic identification
  description text NOT NULL,
  sku text,
  nmfc_code text, -- National Motor Freight Classification
  
  -- Freight class for LTL rating
  freight_class freight_class,
  
  -- Quantity
  quantity integer NOT NULL DEFAULT 1,
  piece_type text DEFAULT 'pallet', -- pallet, box, crate, drum, roll, bundle, etc.
  
  -- Weight
  weight_per_unit numeric,
  total_weight numeric,
  weight_unit text DEFAULT 'lbs' CHECK (weight_unit IN ('lbs', 'kg')),
  
  -- Dimensions (per unit)
  length numeric,
  width numeric,
  height numeric,
  dimension_unit text DEFAULT 'in' CHECK (dimension_unit IN ('in', 'cm', 'ft', 'm')),
  
  -- Calculated volume (cubic)
  volume numeric,
  volume_unit text DEFAULT 'cuft' CHECK (volume_unit IN ('cuft', 'cbm')),
  
  -- Linear feet (for truck space)
  linear_feet numeric,
  
  -- HAZMAT fields
  is_hazmat boolean DEFAULT false,
  hazmat_class text, -- 1-9 DOT hazard class
  hazmat_packing_group hazmat_packing_group,
  un_number text, -- UN identification number (e.g., UN1203)
  hazmat_description text,
  emergency_contact text,
  
  -- Handling requirements
  is_stackable boolean DEFAULT true,
  is_fragile boolean DEFAULT false,
  temperature_requirement temperature_requirement DEFAULT 'none',
  min_temp numeric, -- For custom temp ranges
  max_temp numeric,
  temp_unit text DEFAULT 'F' CHECK (temp_unit IN ('F', 'C')),
  
  -- Value for insurance
  declared_value numeric,
  currency text DEFAULT 'CAD',
  
  -- Notes
  handling_instructions text,
  notes text,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- =============================================================
-- Step 5: Create indexes
-- =============================================================
CREATE INDEX IF NOT EXISTS idx_commodities_company ON public.commodities(company_id);
CREATE INDEX IF NOT EXISTS idx_commodities_load ON public.commodities(load_id) WHERE load_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_commodities_stop ON public.commodities(stop_id) WHERE stop_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_commodities_hazmat ON public.commodities(is_hazmat) WHERE is_hazmat = true;
CREATE INDEX IF NOT EXISTS idx_commodities_freight_class ON public.commodities(freight_class) WHERE freight_class IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_commodities_nmfc ON public.commodities(nmfc_code) WHERE nmfc_code IS NOT NULL;

-- =============================================================
-- Step 6: Enable RLS
-- =============================================================
ALTER TABLE public.commodities ENABLE ROW LEVEL SECURITY;

-- =============================================================
-- Step 7: RLS Policies
-- =============================================================
CREATE POLICY "Users can read commodities in their company"
ON public.commodities FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Users can insert commodities in their company"
ON public.commodities FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Users can update commodities in their company"
ON public.commodities FOR UPDATE
USING (company_id = get_my_company_id());

CREATE POLICY "Users can delete commodities in their company"
ON public.commodities FOR DELETE
USING (company_id = get_my_company_id());

-- =============================================================
-- Step 8: Updated_at trigger
-- =============================================================
CREATE OR REPLACE FUNCTION update_commodity_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  -- Auto-calculate volume if dimensions provided
  IF NEW.length IS NOT NULL AND NEW.width IS NOT NULL AND NEW.height IS NOT NULL THEN
    IF NEW.dimension_unit = 'in' THEN
      NEW.volume := (NEW.length * NEW.width * NEW.height) / 1728; -- cubic feet
      NEW.volume_unit := 'cuft';
    ELSIF NEW.dimension_unit = 'cm' THEN
      NEW.volume := (NEW.length * NEW.width * NEW.height) / 1000000; -- cubic meters
      NEW.volume_unit := 'cbm';
    ELSIF NEW.dimension_unit = 'ft' THEN
      NEW.volume := NEW.length * NEW.width * NEW.height;
      NEW.volume_unit := 'cuft';
    ELSIF NEW.dimension_unit = 'm' THEN
      NEW.volume := NEW.length * NEW.width * NEW.height;
      NEW.volume_unit := 'cbm';
    END IF;
  END IF;
  -- Auto-calculate total weight
  IF NEW.weight_per_unit IS NOT NULL AND NEW.quantity IS NOT NULL THEN
    NEW.total_weight := NEW.weight_per_unit * NEW.quantity;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS commodities_updated_at ON public.commodities;
CREATE TRIGGER commodities_updated_at
BEFORE UPDATE ON public.commodities
FOR EACH ROW EXECUTE FUNCTION update_commodity_updated_at();

-- Also run on insert
DROP TRIGGER IF EXISTS commodities_calculate_on_insert ON public.commodities;
CREATE TRIGGER commodities_calculate_on_insert
BEFORE INSERT ON public.commodities
FOR EACH ROW EXECUTE FUNCTION update_commodity_updated_at();

-- =============================================================
-- Step 9: Webhook trigger
-- =============================================================
DROP TRIGGER IF EXISTS webhook_commodities ON public.commodities;
CREATE TRIGGER webhook_commodities
AFTER INSERT OR UPDATE OR DELETE ON public.commodities
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('commodity');

-- =============================================================
-- Step 10: Comments
-- =============================================================
COMMENT ON TABLE public.commodities IS 'Detailed freight items with freight class, HAZMAT, NMFC for RoseRocket parity';
COMMENT ON COLUMN public.commodities.nmfc_code IS 'National Motor Freight Classification code for LTL rating';
COMMENT ON COLUMN public.commodities.freight_class IS 'Freight Class (50-500) for LTL rating calculations';
COMMENT ON COLUMN public.commodities.hazmat_class IS 'DOT Hazard Class (1-9) for dangerous goods';
COMMENT ON COLUMN public.commodities.un_number IS 'UN identification number for HAZMAT (e.g., UN1203 for gasoline)';
