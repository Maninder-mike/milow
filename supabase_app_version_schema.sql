-- Enhanced app_version table schema with additional useful columns
-- This table tracks the latest app version available for each platform

create table if not exists app_version (
  id bigint generated always as identity primary key,
  platform text not null,              -- 'android' or 'ios'
  latest_version text not null,        -- e.g., 'v1.0.5' or '1.0.5'
  download_url text not null,          -- GitHub release asset URL or app store link
  changelog text,                       -- Optional release notes/changelog
  min_supported_version text,          -- Minimum version that can still run (for force updates)
  is_critical boolean default false,   -- If true, force user to update
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Ensure only one row per platform
create unique index if not exists app_version_platform_idx 
  on app_version (platform);

-- Enable Row Level Security
alter table app_version enable row level security;

-- Allow public read access (so app can check for updates)
create policy "Allow public read access" 
  on app_version for select 
  using (true);

-- Only service role can insert/update (via GitHub Actions)
-- This is automatically handled by Supabase service role key

-- Insert initial row for Android
insert into app_version (platform, latest_version, download_url, changelog, min_supported_version, is_critical)
values (
  'android', 
  'v0.0.1', 
  'https://github.com/maninder-mike/milow/releases/latest',
  'Initial release',
  'v0.0.1',
  false
)
on conflict (platform) do nothing;

-- Function to automatically update the updated_at timestamp
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger to update updated_at on row update
drop trigger if exists update_app_version_updated_at on app_version;
create trigger update_app_version_updated_at
  before update on app_version
  for each row
  execute function update_updated_at_column();
