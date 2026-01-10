-- Fix orphaned profiles by assigning them to the default company (if only one exists or pick first)
-- This fixes the issue where users see 0 customers because of RLS policies requiring a company_id match.

do $$
declare
  v_default_company_id uuid;
begin
  -- Get the first company ID
  select id into v_default_company_id from public.companies limit 1;

  if v_default_company_id is not null then
    -- Update all profiles that don't have a company_id
    update public.profiles
    set company_id = v_default_company_id
    where company_id is null;
    
    -- Also update any customers that might be null (though previous check said 0)
    update public.customers
    set company_id = v_default_company_id
    where company_id is null;
  end if;
end $$;
