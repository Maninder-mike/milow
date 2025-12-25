-- Migration: notify_driver_left_company
-- Description: Creates a trigger to notify company admins when a driver leaves the company

-- Function to notify company admins when a driver leaves
create or replace function public.notify_driver_left_company()
returns trigger as $$
begin
  -- Only trigger when company_id is cleared (driver leaves company)
  if old.company_id is not null and new.company_id is null then
    -- Insert notification for all admins of that company
    insert into public.notifications (user_id, type, title, body, data)
    select 
      p.id,
      'driver_left',
      'Driver Left Company',
      coalesce(old.full_name, 'A driver') || ' has left the company.',
      jsonb_build_object('driver_id', old.id, 'driver_name', old.full_name, 'driver_email', old.email)
    from public.profiles p
    where p.company_id = old.company_id 
      and p.role = 'admin'
      and p.id != old.id;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_driver_left_company on public.profiles;
create trigger on_driver_left_company
  after update on public.profiles
  for each row execute procedure public.notify_driver_left_company();
