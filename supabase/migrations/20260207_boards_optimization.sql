-- Optimizing Boards Feature (RoseRocket Parity)
-- Adds global filters, system protection, widget refresh, drill-down, and performance indexes

-- =============================================================
-- Step 1: Enhance dashboard_boards
-- =============================================================

-- Add global_filters column (jsonb)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_boards' AND column_name = 'global_filters') THEN
        ALTER TABLE public.dashboard_boards ADD COLUMN global_filters jsonb DEFAULT '{}';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_boards' AND column_name = 'is_system') THEN
        ALTER TABLE public.dashboard_boards ADD COLUMN is_system boolean DEFAULT false; -- Protected system boards
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_boards' AND column_name = 'required_permission') THEN
        ALTER TABLE public.dashboard_boards ADD COLUMN required_permission text; -- RBAC for sensitive dashboards
    END IF;
END $$;

-- =============================================================
-- Step 2: Enhance dashboard_widgets
-- =============================================================

-- Add refresh_interval and drill_down
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_widgets' AND column_name = 'refresh_interval_seconds') THEN
        ALTER TABLE public.dashboard_widgets ADD COLUMN refresh_interval_seconds integer DEFAULT 300; -- Default 5 mins
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_widgets' AND column_name = 'drill_down_path') THEN
        ALTER TABLE public.dashboard_widgets ADD COLUMN drill_down_path text; -- Navigation target
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_widgets' AND column_name = 'cache_ttl_seconds') THEN
        ALTER TABLE public.dashboard_widgets ADD COLUMN cache_ttl_seconds integer DEFAULT 60; -- Hint for frontend caching
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_widgets' AND column_name = 'last_refreshed_at') THEN
        ALTER TABLE public.dashboard_widgets ADD COLUMN last_refreshed_at timestamptz;
    END IF;
END $$;

-- =============================================================
-- Step 3: Enhance saved_views
-- =============================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_views' AND column_name = 'last_accessed_at') THEN
        ALTER TABLE public.saved_views ADD COLUMN last_accessed_at timestamptz DEFAULT now();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_views' AND column_name = 'description') THEN
        ALTER TABLE public.saved_views ADD COLUMN description text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'saved_views' AND column_name = 'is_pinnable') THEN
        ALTER TABLE public.saved_views ADD COLUMN is_pinnable boolean DEFAULT true;
    END IF;
END $$;

-- =============================================================
-- Step 4: Performance Indexes
-- =============================================================

-- Optimize fetching visible widgets for a board
CREATE INDEX IF NOT EXISTS idx_widgets_board_visible ON public.dashboard_widgets(board_id) WHERE is_visible = true;

-- Optimize identifying unused views
CREATE INDEX IF NOT EXISTS idx_saved_views_accessed ON public.saved_views(last_accessed_at);

-- =============================================================
-- Step 5: System Protection Trigger
-- =============================================================
-- Prevent deletion of system boards
CREATE OR REPLACE FUNCTION protect_system_boards()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.is_system = true THEN
    RAISE EXCEPTION 'Cannot delete system board: %', OLD.name;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_protect_system_boards ON public.dashboard_boards;
CREATE TRIGGER trigger_protect_system_boards
BEFORE DELETE ON public.dashboard_boards
FOR EACH ROW EXECUTE FUNCTION protect_system_boards();

-- =============================================================
-- Step 6: Comments
-- =============================================================
COMMENT ON COLUMN public.dashboard_boards.global_filters IS 'Context filters (Date, Terminal) applied to all widgets';
COMMENT ON COLUMN public.dashboard_widgets.drill_down_path IS 'Navigation route when widget is clicked';
