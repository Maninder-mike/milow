-- ===========================================================================
-- RoseRocket Parity Migration
-- ===========================================================================
-- This migration adds the following features:
-- 1. Addresses: Normalized address storage
-- 2. Webhooks: Event logging and subscriptions  
-- 3. Dashboard Boards: Customizable dashboards and saved views
-- 4. Tasks: Granular work breakdown within loads
-- ===========================================================================

-- ###########################################################################
-- PART 1: ADDRESSES
-- Normalized address storage for reuse across loads, customers, and partners
-- ###########################################################################

CREATE TABLE IF NOT EXISTS public.addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Core address fields
  name text, -- Location name / Company name
  street_line_1 text NOT NULL,
  street_line_2 text,
  city text NOT NULL,
  state_province text NOT NULL,
  postal_code text NOT NULL,
  country text NOT NULL DEFAULT 'CA',
  
  -- Contact information
  contact_name text,
  contact_phone text,
  contact_email text,
  contact_fax text,
  
  -- Geolocation (for mapping and routing)
  latitude double precision,
  longitude double precision,
  
  -- Address type for classification
  address_type text CHECK (address_type IN ('customer', 'shipper', 'receiver', 'warehouse', 'terminal', 'other')),
  
  -- Audit fields
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- Soft delete
  is_active boolean DEFAULT true
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_addresses_company ON public.addresses(company_id);
CREATE INDEX IF NOT EXISTS idx_addresses_city_state ON public.addresses(city, state_province);
CREATE INDEX IF NOT EXISTS idx_addresses_postal ON public.addresses(postal_code);
CREATE INDEX IF NOT EXISTS idx_addresses_type ON public.addresses(address_type);
CREATE INDEX IF NOT EXISTS idx_addresses_active ON public.addresses(is_active) WHERE is_active = true;

-- RLS
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read addresses in their company"
ON public.addresses FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Users can insert addresses in their company"
ON public.addresses FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Users can update addresses in their company"
ON public.addresses FOR UPDATE
USING (company_id = get_my_company_id());

CREATE POLICY "Users can delete addresses in their company"
ON public.addresses FOR DELETE
USING (company_id = get_my_company_id());

-- Trigger
CREATE OR REPLACE FUNCTION update_addresses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS addresses_updated_at ON public.addresses;
CREATE TRIGGER addresses_updated_at
BEFORE UPDATE ON public.addresses
FOR EACH ROW EXECUTE FUNCTION update_addresses_updated_at();

COMMENT ON TABLE public.addresses IS 'Normalized address storage for reuse across loads, customers, and partners';

-- ###########################################################################
-- PART 2: WEBHOOKS
-- Event logging and subscription infrastructure
-- ###########################################################################

CREATE TABLE IF NOT EXISTS public.webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Event identification
  event_type text NOT NULL,
  object_type text NOT NULL,
  object_id uuid NOT NULL,
  
  -- Payload
  payload jsonb NOT NULL DEFAULT '{}',
  
  -- Delivery status
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'delivered', 'failed', 'retrying')),
  endpoint_url text,
  response_status integer,
  response_body text,
  retry_count integer DEFAULT 0,
  max_retries integer DEFAULT 3,
  last_error text,
  
  -- Timing
  created_at timestamptz DEFAULT now(),
  delivered_at timestamptz,
  next_retry_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.webhook_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Subscription configuration
  name text NOT NULL,
  endpoint_url text NOT NULL,
  secret_key text, -- For HMAC signature verification
  
  -- Event filtering
  event_types text[] NOT NULL DEFAULT ARRAY[]::text[],
  object_types text[] NOT NULL DEFAULT ARRAY[]::text[],
  
  -- Status
  is_active boolean DEFAULT true,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_webhook_events_company ON public.webhook_events(company_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_status ON public.webhook_events(status) WHERE status != 'delivered';
CREATE INDEX IF NOT EXISTS idx_webhook_events_retry ON public.webhook_events(next_retry_at) WHERE status = 'retrying';
CREATE INDEX IF NOT EXISTS idx_webhook_events_object ON public.webhook_events(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_created ON public.webhook_events(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_webhook_subscriptions_company ON public.webhook_subscriptions(company_id);
CREATE INDEX IF NOT EXISTS idx_webhook_subscriptions_active ON public.webhook_subscriptions(is_active) WHERE is_active = true;

-- RLS
ALTER TABLE public.webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Company members can read webhook events"
ON public.webhook_events FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Users can read webhook subscriptions"
ON public.webhook_subscriptions FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Users can insert webhook subscriptions"
ON public.webhook_subscriptions FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Users can update webhook subscriptions"
ON public.webhook_subscriptions FOR UPDATE
USING (company_id = get_my_company_id());

CREATE POLICY "Users can delete webhook subscriptions"
ON public.webhook_subscriptions FOR DELETE
USING (company_id = get_my_company_id());

-- Generic webhook trigger function
CREATE OR REPLACE FUNCTION queue_webhook_event()
RETURNS TRIGGER AS $$
DECLARE
  v_event_type text;
  v_company_id uuid;
  v_object_type text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_event_type := 'created';
  ELSIF TG_OP = 'UPDATE' THEN
    v_event_type := 'updated';
  ELSIF TG_OP = 'DELETE' THEN
    v_event_type := 'deleted';
  END IF;

  v_object_type := TG_ARGV[0];
  
  IF TG_OP = 'DELETE' THEN
    v_company_id := OLD.company_id;
  ELSE
    v_company_id := NEW.company_id;
  END IF;

  IF v_company_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  INSERT INTO public.webhook_events (
    company_id, event_type, object_type, object_id, payload
  ) VALUES (
    v_company_id, v_event_type, v_object_type,
    COALESCE(NEW.id, OLD.id),
    CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END
  );

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create webhook triggers for main tables
DROP TRIGGER IF EXISTS webhook_loads ON public.loads;
CREATE TRIGGER webhook_loads
AFTER INSERT OR UPDATE OR DELETE ON public.loads
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('load');

DROP TRIGGER IF EXISTS webhook_customers ON public.customers;
CREATE TRIGGER webhook_customers
AFTER INSERT OR UPDATE OR DELETE ON public.customers
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('customer');

DROP TRIGGER IF EXISTS webhook_drivers ON public.driver_profiles;
CREATE TRIGGER webhook_drivers
AFTER INSERT OR UPDATE OR DELETE ON public.driver_profiles
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('driver');

DROP TRIGGER IF EXISTS webhook_vehicles ON public.vehicles;
CREATE TRIGGER webhook_vehicles
AFTER INSERT OR UPDATE OR DELETE ON public.vehicles
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('vehicle');

DROP TRIGGER IF EXISTS webhook_documents ON public.documents;
CREATE TRIGGER webhook_documents
AFTER INSERT OR UPDATE OR DELETE ON public.documents
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('document');

DROP TRIGGER IF EXISTS webhook_fuel_entries ON public.fuel_entries;
CREATE TRIGGER webhook_fuel_entries
AFTER INSERT OR UPDATE OR DELETE ON public.fuel_entries
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('fuel_entry');

DROP TRIGGER IF EXISTS webhook_addresses ON public.addresses;
CREATE TRIGGER webhook_addresses
AFTER INSERT OR UPDATE OR DELETE ON public.addresses
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('address');

-- Load status change trigger
CREATE OR REPLACE FUNCTION queue_load_status_webhook()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.webhook_events (
      company_id, event_type, object_type, object_id, payload
    ) VALUES (
      NEW.company_id, 'status.changed', 'load', NEW.id,
      jsonb_build_object(
        'old_status', OLD.status,
        'new_status', NEW.status,
        'load_id', NEW.id,
        'changed_at', now()
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS webhook_load_status ON public.loads;
CREATE TRIGGER webhook_load_status
AFTER UPDATE ON public.loads
FOR EACH ROW EXECUTE FUNCTION queue_load_status_webhook();

-- Subscriptions updated_at trigger
CREATE OR REPLACE FUNCTION update_webhook_subscription_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS webhook_subscriptions_updated_at ON public.webhook_subscriptions;
CREATE TRIGGER webhook_subscriptions_updated_at
BEFORE UPDATE ON public.webhook_subscriptions
FOR EACH ROW EXECUTE FUNCTION update_webhook_subscription_updated_at();

-- ###########################################################################
-- PART 3: DASHBOARD BOARDS
-- Customizable dashboards, widgets, and saved views
-- ###########################################################################

CREATE TABLE IF NOT EXISTS public.dashboard_boards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL = company-wide
  
  -- Board identity
  name text NOT NULL,
  description text,
  icon text,
  
  -- Configuration
  board_type text NOT NULL DEFAULT 'custom' CHECK (board_type IN ('dispatch', 'fleet', 'billing', 'analytics', 'custom')),
  layout jsonb NOT NULL DEFAULT '{"columns": 3}',
  
  -- Ordering
  display_order integer NOT NULL DEFAULT 0,
  
  -- Status
  is_default boolean DEFAULT false,
  is_active boolean DEFAULT true,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.dashboard_widgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id uuid NOT NULL REFERENCES public.dashboard_boards(id) ON DELETE CASCADE,
  
  -- Widget identity
  title text NOT NULL,
  widget_type text NOT NULL CHECK (widget_type IN (
    'stats_card', 'chart', 'table', 'map', 'list', 
    'calendar', 'timeline', 'progress', 'quick_actions'
  )),
  
  -- Data source configuration
  data_source text NOT NULL CHECK (data_source IN (
    'loads', 'drivers', 'trucks', 'trailers', 'customers',
    'invoices', 'fuel_entries', 'settlements', 'trips'
  )),
  query_config jsonb NOT NULL DEFAULT '{}',
  
  -- Position in grid
  grid_x integer NOT NULL DEFAULT 0,
  grid_y integer NOT NULL DEFAULT 0,
  grid_width integer NOT NULL DEFAULT 1,
  grid_height integer NOT NULL DEFAULT 1,
  
  -- Appearance
  config jsonb NOT NULL DEFAULT '{}',
  
  -- Status
  is_visible boolean DEFAULT true,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.saved_views (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- View identity
  name text NOT NULL,
  view_type text NOT NULL CHECK (view_type IN ('loads', 'drivers', 'customers', 'trucks', 'trailers', 'invoices')),
  
  -- View configuration
  columns jsonb NOT NULL DEFAULT '[]',
  filters jsonb NOT NULL DEFAULT '{}',
  sort_config jsonb NOT NULL DEFAULT '{}',
  
  -- Status
  is_default boolean DEFAULT false,
  is_shared boolean DEFAULT false,
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_boards_company ON public.dashboard_boards(company_id);
CREATE INDEX IF NOT EXISTS idx_boards_user ON public.dashboard_boards(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_boards_active ON public.dashboard_boards(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_boards_order ON public.dashboard_boards(company_id, display_order);

CREATE INDEX IF NOT EXISTS idx_widgets_board ON public.dashboard_widgets(board_id);
CREATE INDEX IF NOT EXISTS idx_widgets_visible ON public.dashboard_widgets(is_visible) WHERE is_visible = true;

CREATE INDEX IF NOT EXISTS idx_saved_views_company ON public.saved_views(company_id);
CREATE INDEX IF NOT EXISTS idx_saved_views_user ON public.saved_views(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_saved_views_type ON public.saved_views(view_type);

-- RLS
ALTER TABLE public.dashboard_boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read company and own boards"
ON public.dashboard_boards FOR SELECT
USING (
  (user_id IS NULL AND company_id = get_my_company_id())
  OR user_id = auth.uid()
);

CREATE POLICY "Users can manage own boards"
ON public.dashboard_boards FOR ALL
USING (user_id = auth.uid());

CREATE POLICY "Company members can manage company boards"
ON public.dashboard_boards FOR ALL
USING (user_id IS NULL AND company_id = get_my_company_id());

CREATE POLICY "Users can read widgets on accessible boards"
ON public.dashboard_widgets FOR SELECT
USING (board_id IN (
  SELECT id FROM public.dashboard_boards WHERE 
    user_id = auth.uid() 
    OR (user_id IS NULL AND company_id = get_my_company_id())
));

CREATE POLICY "Users can manage widgets on own boards"
ON public.dashboard_widgets FOR ALL
USING (board_id IN (SELECT id FROM public.dashboard_boards WHERE user_id = auth.uid()));

CREATE POLICY "Users can manage widgets on company boards"
ON public.dashboard_widgets FOR ALL
USING (board_id IN (
  SELECT id FROM public.dashboard_boards 
  WHERE user_id IS NULL AND company_id = get_my_company_id()
));

CREATE POLICY "Users can read own and shared views"
ON public.saved_views FOR SELECT
USING (
  user_id = auth.uid()
  OR (is_shared = true AND company_id = get_my_company_id())
);

CREATE POLICY "Users can manage own views"
ON public.saved_views FOR ALL
USING (user_id = auth.uid());

-- Board updated_at trigger
CREATE OR REPLACE FUNCTION update_board_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS boards_updated_at ON public.dashboard_boards;
CREATE TRIGGER boards_updated_at
BEFORE UPDATE ON public.dashboard_boards
FOR EACH ROW EXECUTE FUNCTION update_board_updated_at();

DROP TRIGGER IF EXISTS widgets_updated_at ON public.dashboard_widgets;
CREATE TRIGGER widgets_updated_at
BEFORE UPDATE ON public.dashboard_widgets
FOR EACH ROW EXECUTE FUNCTION update_board_updated_at();

DROP TRIGGER IF EXISTS saved_views_updated_at ON public.saved_views;
CREATE TRIGGER saved_views_updated_at
BEFORE UPDATE ON public.saved_views
FOR EACH ROW EXECUTE FUNCTION update_board_updated_at();

-- ###########################################################################
-- PART 4: TASKS
-- Granular work breakdown within loads with subtask support
-- ###########################################################################

-- Create enums
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_type') THEN
    CREATE TYPE task_type AS ENUM (
      'pickup', 'delivery', 'inspection', 'documentation', 'customs',
      'fuel_stop', 'rest_break', 'equipment_check', 'weigh_station',
      'signature_collection', 'photo_capture', 'other'
    );
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN
    CREATE TYPE task_status AS ENUM (
      'pending', 'in_progress', 'completed', 'failed', 'skipped', 'cancelled'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.tasks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  
  -- Parent associations
  load_id uuid REFERENCES public.loads(id) ON DELETE CASCADE,
  stop_id uuid REFERENCES public.stops(id) ON DELETE SET NULL,
  parent_task_id uuid REFERENCES public.tasks(id) ON DELETE CASCADE, -- For subtasks
  
  -- Task identity
  title text NOT NULL,
  description text,
  task_type task_type NOT NULL DEFAULT 'other',
  status task_status NOT NULL DEFAULT 'pending',
  
  -- Ordering
  sequence_order integer NOT NULL DEFAULT 0,
  
  -- Assignment
  assigned_driver_id uuid REFERENCES public.driver_profiles(id) ON DELETE SET NULL,
  
  -- Scheduling
  scheduled_at timestamptz,
  due_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  
  -- Duration tracking
  estimated_duration_minutes integer,
  actual_duration_minutes integer,
  
  -- Location (optional)
  location_name text,
  location_address text,
  latitude double precision,
  longitude double precision,
  
  -- Required actions
  requires_signature boolean DEFAULT false,
  requires_photo boolean DEFAULT false,
  requires_scan boolean DEFAULT false,
  
  -- Completion data
  signature_url text,
  photo_urls jsonb DEFAULT '[]',
  notes text,
  completion_data jsonb DEFAULT '{}',
  
  -- Audit
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  completed_by uuid REFERENCES auth.users(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tasks_company ON public.tasks(company_id);
CREATE INDEX IF NOT EXISTS idx_tasks_load ON public.tasks(load_id);
CREATE INDEX IF NOT EXISTS idx_tasks_stop ON public.tasks(stop_id) WHERE stop_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_parent ON public.tasks(parent_task_id) WHERE parent_task_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_driver ON public.tasks(assigned_driver_id) WHERE assigned_driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_type ON public.tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_tasks_sequence ON public.tasks(load_id, sequence_order);
CREATE INDEX IF NOT EXISTS idx_tasks_scheduled ON public.tasks(scheduled_at) WHERE scheduled_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_pending ON public.tasks(status, due_at) WHERE status = 'pending';

-- RLS
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read tasks in their company"
ON public.tasks FOR SELECT
USING (company_id = get_my_company_id());

CREATE POLICY "Users can insert tasks in their company"
ON public.tasks FOR INSERT
WITH CHECK (company_id = get_my_company_id());

CREATE POLICY "Users can update tasks in their company"
ON public.tasks FOR UPDATE
USING (company_id = get_my_company_id());

CREATE POLICY "Users can delete tasks in their company"
ON public.tasks FOR DELETE
USING (company_id = get_my_company_id());

CREATE POLICY "Drivers can update assigned tasks"
ON public.tasks FOR UPDATE
USING (assigned_driver_id = auth.uid())
WITH CHECK (assigned_driver_id = auth.uid());

-- Task updated_at trigger
CREATE OR REPLACE FUNCTION update_task_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tasks_updated_at ON public.tasks;
CREATE TRIGGER tasks_updated_at
BEFORE UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION update_task_updated_at();

-- Task webhook trigger
DROP TRIGGER IF EXISTS webhook_tasks ON public.tasks;
CREATE TRIGGER webhook_tasks
AFTER INSERT OR UPDATE OR DELETE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION queue_webhook_event('task');

COMMENT ON TABLE public.tasks IS 'Granular work breakdown within loads for RoseRocket parity';
COMMENT ON COLUMN public.tasks.parent_task_id IS 'For subtasks - allows nested task hierarchy';
