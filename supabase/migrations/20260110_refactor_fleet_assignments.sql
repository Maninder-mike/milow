-- Rename table
alter table driver_vehicle_assignments rename to fleet_assignments;

-- Create enum type for assignment types
create type assignment_type as enum (
  'driver_to_vehicle',   -- Driver assigned to Truck
  'vehicle_to_vehicle',  -- Truck assigned to Trailer
  'trip_assignment',     -- Resources assigned to a Trip
  'co_driver'            -- Secondary driver
);

-- Add new columns
alter table fleet_assignments 
  add column if not exists type assignment_type not null default 'driver_to_vehicle',
  add column if not exists trip_number text,
  
  -- Add generic assignee_id (renaming driver_id effectively, but let's keep it safe)
  -- Strategy: Add new UUID columns, migrate data, drop old ones (or keep mapped)
  -- For cleaner code refactor, we will rename the existing columns to be generic
  rename column driver_id to assignee_id;

alter table fleet_assignments
  rename column vehicle_id to resource_id;

-- Make assignee_id nullable because a Trip Assignment might strictly be "Truck 101 on Trip 555" (resource only?)
-- Actually trip assignment usually links resource to trip. Who is assignee?
-- If Trip is the context, maybe we just need resource_id + trip_number.
-- So assignee_id should be nullable.
alter table fleet_assignments alter column assignee_id drop not null;

-- Add index for trip lookups
create index idx_fleet_assignments_trip_number on fleet_assignments(trip_number);
create index idx_fleet_assignments_type on fleet_assignments(type);

-- Comment on table
comment on table fleet_assignments is 'Unified table for all fleet assignments (Drivers, Vehicles, Trips)';
