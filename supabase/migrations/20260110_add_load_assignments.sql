-- Add assigned_truck_id and assigned_trailer_id to loads table
ALTER TABLE loads
ADD COLUMN IF NOT EXISTS assigned_truck_id UUID REFERENCES vehicles(id),
ADD COLUMN IF NOT EXISTS assigned_trailer_id UUID REFERENCES vehicles(id);
