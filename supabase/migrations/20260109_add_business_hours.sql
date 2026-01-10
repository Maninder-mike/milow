-- Add business_hours column to customers table
alter table public.customers 
add column if not exists business_hours text;

-- Comment
comment on column public.customers.business_hours is 'Operating hours of the customer facility';
