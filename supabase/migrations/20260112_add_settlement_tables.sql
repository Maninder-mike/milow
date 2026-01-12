-- Create Driver Pay Configs Table
CREATE TABLE IF NOT EXISTS public.driver_pay_configs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id uuid REFERENCES auth.users(id) NOT NULL UNIQUE,
    pay_type text NOT NULL CHECK (pay_type IN ('percentage', 'cpm', 'flat')),
    pay_value numeric NOT NULL DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create Driver Settlements Table
CREATE TABLE IF NOT EXISTS public.driver_settlements (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id uuid REFERENCES auth.users(id) NOT NULL,
    status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'paid', 'void')),
    start_date timestamptz NOT NULL,
    end_date timestamptz NOT NULL,
    total_earnings numeric NOT NULL DEFAULT 0,
    total_deductions numeric NOT NULL DEFAULT 0,
    net_payout numeric NOT NULL DEFAULT 0,
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Create Settlement Items Table
CREATE TABLE IF NOT EXISTS public.settlement_items (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    settlement_id uuid REFERENCES public.driver_settlements(id) ON DELETE CASCADE,
    type text NOT NULL CHECK (type IN ('loadPay', 'fuelDeduction', 'otherEarnings', 'otherDeduction')),
    description text NOT NULL,
    amount numeric NOT NULL,
    reference_id text, -- ID of the load or fuel entry
    created_at timestamptz DEFAULT now()
);

-- RLS Policies
ALTER TABLE public.driver_pay_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlement_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable all access for authenticated users" ON public.driver_pay_configs FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all access for authenticated users" ON public.driver_settlements FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all access for authenticated users" ON public.settlement_items FOR ALL USING (auth.role() = 'authenticated');

-- RPC: Get Unsettled Loads
-- Assumes 'loads' table exists and has 'status' and 'driver_id'
-- And assumes 'settlement_items' links via reference_id
CREATE OR REPLACE FUNCTION get_unsettled_loads(p_driver_id uuid)
RETURNS TABLE (
    id uuid,
    trip_number text,
    load_reference text,
    rate numeric,
    status text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.trip_number::text,
        l.customer_reference::text as load_reference,
        l.rate,
        l.status::text
    FROM public.loads l
    WHERE l.driver_assigned_id = p_driver_id
    AND l.status = 'delivered'
    AND NOT EXISTS (
        SELECT 1 FROM public.settlement_items si 
        WHERE si.reference_id = l.id::text 
        AND si.type = 'loadPay'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Get Unsettled Fuel
CREATE OR REPLACE FUNCTION get_unsettled_fuel(p_driver_id uuid)
RETURNS TABLE (
    id uuid,
    truck_number text,
    location text,
    total_cost numeric,
    transaction_date timestamptz
) AS $$
BEGIN
    -- This is a placeholder since we don't know the exact fuel table schema yet
    -- Returning empty for now if table doesn't exist, or standard select if it does
    -- Assuming a 'fuel_entries' table exists. Adjust as needed.
    RETURN QUERY
    SELECT 
        f.id,
        f.truck_number::text,
        f.merchant_name || ', ' || f.merchant_city || ' ' || f.merchant_state as location,
        f.amount as total_cost,
        f.transaction_date
    FROM public.fuel_cards_transactions f
    WHERE f.driver_id = p_driver_id
    AND NOT EXISTS (
        SELECT 1 FROM public.settlement_items si 
        WHERE si.reference_id = f.id::text 
        AND si.type = 'fuelDeduction'
    );
EXCEPTION 
    WHEN OTHERS THEN
        RETURN; -- Return nothing if table doesn't exist
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
