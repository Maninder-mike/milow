-- Add missing logistics flags to customers table to support Shipper/Receiver profiles
alter table public.customers 
add column if not exists is_ppe_required boolean default false,
add column if not exists is_driver_assist boolean default false,
add column if not exists is_overnight_parking boolean default false,
add column if not exists is_strict_late_policy boolean default false,
add column if not exists is_call_before_arrival boolean default false,
add column if not exists is_blind_shipment boolean default false,
add column if not exists is_scale_on_site boolean default false,
add column if not exists is_clean_trailer boolean default false,
add column if not exists is_facility_247 boolean default false,
add column if not exists is_straps_required boolean default false,
add column if not exists is_lumper_required boolean default false,
add column if not exists is_gate_code_required boolean default false;

comment on column public.customers.is_ppe_required is 'Safety gear required';
comment on column public.customers.is_driver_assist is 'Driver must help load/unload';
comment on column public.customers.is_lumper_required is 'Lumper service required (Receiver)';
