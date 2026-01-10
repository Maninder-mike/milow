-- Add customer_type column to customers table
alter table public.customers 
add column if not exists customer_type text default 'Shipper' check (customer_type in ('Shipper', 'Broker', 'Receiver', 'Other'));

-- Comment
comment on column public.customers.customer_type is 'Type of customer: Shipper, Broker, Receiver, or Other';
