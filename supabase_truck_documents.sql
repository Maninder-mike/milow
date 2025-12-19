-- TRUCK DOCUMENTS TABLE
create table if not exists public.truck_documents (
    id uuid default gen_random_uuid() primary key,
    truck_id uuid references public.trucks(id) on delete cascade not null,
    company_id uuid references public.companies(id) not null, -- Denormalized for easier RLS
    document_type text not null, -- 'Registration', 'Insurance', 'Inspection', 'Other'
    file_path text not null,
    expiry_date date,
    notes text,
    created_at timestamptz default now()
);

-- ENABLE RLS
alter table public.truck_documents enable row level security;

-- POLICIES FOR TRUCK DOCUMENTS
create policy "Company members can view truck documents"
  on public.truck_documents for select using (
    company_id in (select company_id from public.profiles where id = auth.uid())
  );

create policy "Company members can insert truck documents"
  on public.truck_documents for insert with check (
    company_id in (select company_id from public.profiles where id = auth.uid())
  );

create policy "Company members can update truck documents"
  on public.truck_documents for update using (
    company_id in (select company_id from public.profiles where id = auth.uid())
  );

create policy "Company members can delete truck documents"
  on public.truck_documents for delete using (
    company_id in (select company_id from public.profiles where id = auth.uid())
  );

-- STORAGE for Truck Documents
insert into storage.buckets (id, name, public) values ('truck_documents', 'truck_documents', false)
on conflict (id) do nothing;

create policy "Company members can view truck documents storage"
  on storage.objects for select using (
    bucket_id = 'truck_documents' and
    (storage.foldername(name))[1] in (
       select company_id::text from public.profiles where id = auth.uid()
    )
  );

create policy "Company members can upload truck documents storage"
  on storage.objects for insert with check (
    bucket_id = 'truck_documents' and
    (storage.foldername(name))[1] in (
       select company_id::text from public.profiles where id = auth.uid()
    )
  );

create policy "Company members can delete truck documents storage"
  on storage.objects for delete using (
    bucket_id = 'truck_documents' and
    (storage.foldername(name))[1] in (
       select company_id::text from public.profiles where id = auth.uid()
    )
  );

-- TRIGGER to auto-set company_id on truck_documents
create or replace function public.set_truck_doc_company_id()
returns trigger as $$
begin
  if new.company_id is null then
    select company_id into new.company_id from public.profiles where id = auth.uid();
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists set_truck_doc_company_id_trigger on public.truck_documents;
create trigger set_truck_doc_company_id_trigger
  before insert on public.truck_documents
  for each row execute procedure public.set_truck_doc_company_id();
