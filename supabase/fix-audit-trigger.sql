-- Fix for log_supervisor_edit function to handle tables with sheet_id as primary key
-- This fixes the "record 'new' has no field 'id'" error

CREATE OR REPLACE FUNCTION log_supervisor_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sheet_id UUID;
  v_user_role TEXT;
  v_record_id UUID;
BEGIN
  -- Get current user role
  SELECT role INTO v_user_role FROM current_profile LIMIT 1;
  
  -- Only log if user is a supervisor
  IF v_user_role = 'supervisor' THEN
    -- Determine sheet_id based on table
    CASE TG_TABLE_NAME
      WHEN 'daily_sheets' THEN
        v_sheet_id := COALESCE(NEW.id, OLD.id);
        v_record_id := COALESCE(NEW.id, OLD.id);
      WHEN 'pastry_lines', 'yoghurt_container_lines', 
           'yoghurt_refill_lines', 'yoghurt_non_container', 'yoghurt_section_b_income',
           'material_lines', 'currency_notes', 'staff_attendance', 'extra_expenses' THEN
        v_sheet_id := COALESCE(NEW.sheet_id, OLD.sheet_id);
        v_record_id := COALESCE(NEW.id, OLD.id);
      WHEN 'yoghurt_headers' THEN
        v_sheet_id := COALESCE(NEW.sheet_id, OLD.sheet_id);
        v_record_id := COALESCE(NEW.sheet_id, OLD.sheet_id); -- yoghurt_headers uses sheet_id as primary key
      ELSE
        v_sheet_id := NULL;
        v_record_id := NULL;
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
        v_record_id,
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
