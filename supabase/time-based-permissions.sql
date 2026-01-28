-- ============================================================================
-- Time-based Permissions and Audit Logging Migration
-- ============================================================================
-- This migration adds:
-- 1. Audit log table for tracking supervisor edits
-- 2. Time-based permission functions
-- 3. Updated RLS policies for time-based access control
-- ============================================================================

-- ============================================================================
-- STEP 1: Create audit log table
-- ============================================================================

CREATE TABLE IF NOT EXISTS sheet_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sheet_id UUID NOT NULL REFERENCES daily_sheets(id) ON DELETE CASCADE,
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
  old_values JSONB,
  new_values JSONB,
  changed_by UUID NOT NULL REFERENCES auth.users(id),
  changed_by_role TEXT NOT NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_sheet FOREIGN KEY (sheet_id) REFERENCES daily_sheets(id) ON DELETE CASCADE
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_sheet_audit_logs_sheet_id ON sheet_audit_logs(sheet_id);
CREATE INDEX IF NOT EXISTS idx_sheet_audit_logs_changed_at ON sheet_audit_logs(changed_at);
CREATE INDEX IF NOT EXISTS idx_sheet_audit_logs_changed_by ON sheet_audit_logs(changed_by);

-- Enable RLS on audit logs
ALTER TABLE sheet_audit_logs ENABLE ROW LEVEL SECURITY;

-- Supervisors can view all audit logs, branch users can view logs for their branch
CREATE POLICY "audit_logs_select" ON sheet_audit_logs
FOR SELECT USING (
  EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
  OR EXISTS (
    SELECT 1 FROM current_profile cp
    JOIN daily_sheets ds ON ds.id = sheet_audit_logs.sheet_id
    WHERE cp.branch_id = ds.branch_id
  )
);

-- Only system can insert audit logs (via triggers)
CREATE POLICY "audit_logs_insert" ON sheet_audit_logs
FOR INSERT WITH CHECK (true);

-- ============================================================================
-- STEP 2: Create helper functions for time-based permissions
-- ============================================================================

-- Function to check if a sheet is still editable by branch users (same day before midnight)
CREATE OR REPLACE FUNCTION is_sheet_editable_by_branch_user(p_sheet_date DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Branch users can edit until 11:59:59 PM of the same day
  RETURN CURRENT_DATE = p_sheet_date;
END;
$$;

-- Function to check if a sheet is editable by supervisor (next day onwards)
CREATE OR REPLACE FUNCTION is_sheet_editable_by_supervisor(p_sheet_date DATE)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Supervisors can edit from 12:00 AM of the next day onwards
  RETURN CURRENT_DATE > p_sheet_date;
END;
$$;

-- ============================================================================
-- STEP 3: Create audit trigger function
-- ============================================================================

CREATE OR REPLACE FUNCTION log_supervisor_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sheet_id UUID;
  v_user_role TEXT;
BEGIN
  -- Get current user role
  SELECT role INTO v_user_role FROM current_profile LIMIT 1;
  
  -- Only log if user is a supervisor
  IF v_user_role = 'supervisor' THEN
    -- Determine sheet_id based on table
    CASE TG_TABLE_NAME
      WHEN 'daily_sheets' THEN
        v_sheet_id := COALESCE(NEW.id, OLD.id);
      WHEN 'pastry_lines', 'yoghurt_headers', 'yoghurt_container_lines', 
           'yoghurt_refill_lines', 'yoghurt_non_container', 'yoghurt_section_b_income',
           'material_lines', 'currency_notes', 'staff_attendance', 'extra_expenses' THEN
        v_sheet_id := COALESCE(NEW.sheet_id, OLD.sheet_id);
      ELSE
        v_sheet_id := NULL;
    END CASE;
    
    -- Insert audit log
    IF v_sheet_id IS NOT NULL THEN
      INSERT INTO sheet_audit_logs (
        sheet_id,
        table_name,
        record_id,
        action,
        old_values,
        new_values,
        changed_by,
        changed_by_role
      ) VALUES (
        v_sheet_id,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        auth.uid(),
        v_user_role
      );
    END IF;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- ============================================================================
-- STEP 4: Create audit triggers on all sheet-related tables
-- ============================================================================

-- Daily sheets
DROP TRIGGER IF EXISTS trg_audit_daily_sheets ON daily_sheets;
CREATE TRIGGER trg_audit_daily_sheets
AFTER INSERT OR UPDATE OR DELETE ON daily_sheets
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Pastry lines
DROP TRIGGER IF EXISTS trg_audit_pastry_lines ON pastry_lines;
CREATE TRIGGER trg_audit_pastry_lines
AFTER INSERT OR UPDATE OR DELETE ON pastry_lines
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Yoghurt headers
DROP TRIGGER IF EXISTS trg_audit_yoghurt_headers ON yoghurt_headers;
CREATE TRIGGER trg_audit_yoghurt_headers
AFTER INSERT OR UPDATE OR DELETE ON yoghurt_headers
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Yoghurt container lines
DROP TRIGGER IF EXISTS trg_audit_yoghurt_container_lines ON yoghurt_container_lines;
CREATE TRIGGER trg_audit_yoghurt_container_lines
AFTER INSERT OR UPDATE OR DELETE ON yoghurt_container_lines
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Yoghurt refill lines
DROP TRIGGER IF EXISTS trg_audit_yoghurt_refill_lines ON yoghurt_refill_lines;
CREATE TRIGGER trg_audit_yoghurt_refill_lines
AFTER INSERT OR UPDATE OR DELETE ON yoghurt_refill_lines
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Yoghurt non-container
DROP TRIGGER IF EXISTS trg_audit_yoghurt_non_container ON yoghurt_non_container;
CREATE TRIGGER trg_audit_yoghurt_non_container
AFTER INSERT OR UPDATE OR DELETE ON yoghurt_non_container
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Yoghurt section B income
DROP TRIGGER IF EXISTS trg_audit_yoghurt_section_b_income ON yoghurt_section_b_income;
CREATE TRIGGER trg_audit_yoghurt_section_b_income
AFTER INSERT OR UPDATE OR DELETE ON yoghurt_section_b_income
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Material lines
DROP TRIGGER IF EXISTS trg_audit_material_lines ON material_lines;
CREATE TRIGGER trg_audit_material_lines
AFTER INSERT OR UPDATE OR DELETE ON material_lines
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Currency notes
DROP TRIGGER IF EXISTS trg_audit_currency_notes ON currency_notes;
CREATE TRIGGER trg_audit_currency_notes
AFTER INSERT OR UPDATE OR DELETE ON currency_notes
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Staff attendance
DROP TRIGGER IF EXISTS trg_audit_staff_attendance ON staff_attendance;
CREATE TRIGGER trg_audit_staff_attendance
AFTER INSERT OR UPDATE OR DELETE ON staff_attendance
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- Extra expenses
DROP TRIGGER IF EXISTS trg_audit_extra_expenses ON extra_expenses;
CREATE TRIGGER trg_audit_extra_expenses
AFTER INSERT OR UPDATE OR DELETE ON extra_expenses
FOR EACH ROW EXECUTE FUNCTION log_supervisor_edit();

-- ============================================================================
-- STEP 5: Update RLS policies for time-based permissions
-- ============================================================================

-- Update daily_sheets UPDATE policy
DROP POLICY IF EXISTS "sheets_update" ON daily_sheets;
CREATE POLICY "sheets_update" ON daily_sheets
FOR UPDATE USING (
  -- Branch users can update their own branch's sheets on the same day
  (
    branch_id = (SELECT branch_id FROM current_profile)
    AND is_sheet_editable_by_branch_user(sheet_date)
  )
  -- Supervisors can update any sheet from the next day onwards
  OR (
    EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
    AND is_sheet_editable_by_supervisor(sheet_date)
  )
) WITH CHECK (
  -- Same conditions for the new state
  (
    branch_id = (SELECT branch_id FROM current_profile)
    AND is_sheet_editable_by_branch_user(sheet_date)
  )
  OR (
    EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
    AND is_sheet_editable_by_supervisor(sheet_date)
  )
);

-- Update policies for all line tables to respect time-based permissions
-- These policies check the sheet_date from the parent daily_sheets table

-- Pastry lines
DROP POLICY IF EXISTS "pastry_lines_update" ON pastry_lines;
CREATE POLICY "pastry_lines_update" ON pastry_lines
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = pastry_lines.sheet_id
  )
);

-- Yoghurt headers
DROP POLICY IF EXISTS "yoghurt_headers_update" ON yoghurt_headers;
CREATE POLICY "yoghurt_headers_update" ON yoghurt_headers
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = yoghurt_headers.sheet_id
  )
);

-- Yoghurt container lines
DROP POLICY IF EXISTS "yoghurt_container_lines_update" ON yoghurt_container_lines;
CREATE POLICY "yoghurt_container_lines_update" ON yoghurt_container_lines
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = yoghurt_container_lines.sheet_id
  )
);

-- Yoghurt refill lines
DROP POLICY IF EXISTS "yoghurt_refill_lines_update" ON yoghurt_refill_lines;
CREATE POLICY "yoghurt_refill_lines_update" ON yoghurt_refill_lines
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = yoghurt_refill_lines.sheet_id
  )
);

-- Yoghurt non-container
DROP POLICY IF EXISTS "yoghurt_non_container_update" ON yoghurt_non_container;
CREATE POLICY "yoghurt_non_container_update" ON yoghurt_non_container
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = yoghurt_non_container.sheet_id
  )
);

-- Yoghurt section B income
DROP POLICY IF EXISTS "yoghurt_section_b_income_update" ON yoghurt_section_b_income;
CREATE POLICY "yoghurt_section_b_income_update" ON yoghurt_section_b_income
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = yoghurt_section_b_income.sheet_id
  )
);

-- Material lines
DROP POLICY IF EXISTS "material_lines_update" ON material_lines;
CREATE POLICY "material_lines_update" ON material_lines
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = material_lines.sheet_id
  )
);

-- Currency notes
DROP POLICY IF EXISTS "currency_notes_update" ON currency_notes;
CREATE POLICY "currency_notes_update" ON currency_notes
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = currency_notes.sheet_id
  )
);

-- Staff attendance
DROP POLICY IF EXISTS "staff_attendance_update" ON staff_attendance;
CREATE POLICY "staff_attendance_update" ON staff_attendance
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = staff_attendance.sheet_id
  )
);

-- Extra expenses
DROP POLICY IF EXISTS "extra_expenses_update" ON extra_expenses;
CREATE POLICY "extra_expenses_update" ON extra_expenses
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM daily_sheets ds
    JOIN current_profile cp ON (
      (ds.branch_id = cp.branch_id AND is_sheet_editable_by_branch_user(ds.sheet_date))
      OR (cp.role = 'supervisor' AND is_sheet_editable_by_supervisor(ds.sheet_date))
    )
    WHERE ds.id = extra_expenses.sheet_id
  )
);

-- ============================================================================
-- DONE! Time-based permissions and audit logging are now active.
-- ============================================================================

SELECT 'Time-based permissions migration completed successfully!' AS status;
