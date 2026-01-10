-- Add unique constraint for upsert operations
ALTER TABLE fleet_assignments
ADD CONSTRAINT fleet_assignments_assignment_key UNIQUE (assignee_id, trip_number, type);
