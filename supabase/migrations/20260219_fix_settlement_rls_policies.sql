-- Helper function to get user role from profile
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS TEXT AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role FROM public.profiles WHERE id = auth.uid();
  RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop the existing permissive policies
DROP POLICY "Enable all access for authenticated users" ON public.driver_pay_configs;
DROP POLICY "Enable all access for authenticated users" ON public.driver_settlements;
DROP POLICY "Enable all access for authenticated users" ON public.settlement_items;

-- Create new policies for driver_pay_configs
CREATE POLICY "Admins have full access to pay configs" ON public.driver_pay_configs
  FOR ALL
  USING (get_user_role() = 'admin');

CREATE POLICY "Drivers can view their own pay configs" ON public.driver_pay_configs
  FOR SELECT
  USING (driver_id = auth.uid());

-- Create new policies for driver_settlements
CREATE POLICY "Admins have full access to settlements" ON public.driver_settlements
  FOR ALL
  USING (get_user_role() = 'admin');

CREATE POLICY "Drivers can view their own settlements" ON public.driver_settlements
  FOR SELECT
  USING (driver_id = auth.uid());

-- Create new policies for settlement_items
CREATE POLICY "Admins have full access to settlement items" ON public.settlement_items
  FOR ALL
  USING (get_user_role() = 'admin');

CREATE POLICY "Drivers can view their own settlement items" ON public.settlement_items
  FOR SELECT
  USING (
    settlement_id IN (
      SELECT id FROM public.driver_settlements WHERE driver_id = auth.uid()
    )
  );
