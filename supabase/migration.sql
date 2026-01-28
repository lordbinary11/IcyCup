-- Migration script: Transition from trigger-based schema to frontend-calculation schema
-- Run this AFTER the old schema.sql has been applied
-- This script:
-- 1. Drops all computation triggers
-- 2. Drops unused functions
-- 3. Adds item_name columns to line tables
-- 4. Populates item_name from items table
-- 5. Updates RLS policies

-- ============================================================================
-- STEP 1: Drop all computation triggers
-- ============================================================================

-- Pastry triggers
DROP TRIGGER IF EXISTS trg_pastry_lines_biud ON pastry_lines;
DROP TRIGGER IF EXISTS trg_pastry_lines_totals ON pastry_lines;
DROP TRIGGER IF EXISTS trg_totals_pastry ON pastry_lines;
DROP TRIGGER IF EXISTS trg_audit_pastry_lines ON pastry_lines;

-- Yoghurt triggers
DROP TRIGGER IF EXISTS trg_yoghurt_headers_biud ON yoghurt_headers;
DROP TRIGGER IF EXISTS trg_yoghurt_container_biud ON yoghurt_container_lines;
DROP TRIGGER IF EXISTS trg_yoghurt_refill_biud ON yoghurt_refill_lines;
DROP TRIGGER IF EXISTS trg_yoghurt_nc_biud ON yoghurt_non_container;
DROP TRIGGER IF EXISTS trg_yoghurt_section_b_biud ON yoghurt_section_b_income;
DROP TRIGGER IF EXISTS trg_totals_yc ON yoghurt_container_lines;
DROP TRIGGER IF EXISTS trg_totals_yrefill ON yoghurt_refill_lines;
DROP TRIGGER IF EXISTS trg_totals_ync ON yoghurt_non_container;
DROP TRIGGER IF EXISTS trg_totals_yb ON yoghurt_section_b_income;
DROP TRIGGER IF EXISTS trg_audit_yoghurt_headers ON yoghurt_headers;
DROP TRIGGER IF EXISTS trg_audit_yoghurt_container_lines ON yoghurt_container_lines;
DROP TRIGGER IF EXISTS trg_audit_yoghurt_refill_lines ON yoghurt_refill_lines;
DROP TRIGGER IF EXISTS trg_audit_yoghurt_non_container ON yoghurt_non_container;
DROP TRIGGER IF EXISTS trg_audit_yoghurt_section_b_income ON yoghurt_section_b_income;

-- Material triggers
DROP TRIGGER IF EXISTS trg_material_lines_biud ON material_lines;
DROP TRIGGER IF EXISTS trg_audit_material_lines ON material_lines;

-- Currency triggers
DROP TRIGGER IF EXISTS trg_currency_notes_biud ON currency_notes;
DROP TRIGGER IF EXISTS trg_totals_currency ON currency_notes;
DROP TRIGGER IF EXISTS trg_audit_currency_notes ON currency_notes;

-- Other audit triggers
DROP TRIGGER IF EXISTS trg_audit_daily_sheets ON daily_sheets;
DROP TRIGGER IF EXISTS trg_audit_staff_attendance ON staff_attendance;
DROP TRIGGER IF EXISTS trg_audit_extra_expenses ON extra_expenses;
DROP TRIGGER IF EXISTS trg_audit_item_versions ON item_versions;

-- ============================================================================
-- STEP 2: Drop unused functions
-- ============================================================================

DROP FUNCTION IF EXISTS pastry_lines_biud() CASCADE;
DROP FUNCTION IF EXISTS update_pastries_total() CASCADE;
DROP FUNCTION IF EXISTS yoghurt_headers_biud() CASCADE;
DROP FUNCTION IF EXISTS yoghurt_lines_biud() CASCADE;
DROP FUNCTION IF EXISTS yoghurt_non_container_biud() CASCADE;
DROP FUNCTION IF EXISTS yoghurt_section_b_biud() CASCADE;
DROP FUNCTION IF EXISTS recompute_sheet_totals() CASCADE;
DROP FUNCTION IF EXISTS material_lines_biud() CASCADE;
DROP FUNCTION IF EXISTS currency_notes_biud() CASCADE;
DROP FUNCTION IF EXISTS audit_trigger() CASCADE;
DROP FUNCTION IF EXISTS get_daily_sheet_full(uuid) CASCADE;
DROP FUNCTION IF EXISTS get_active_item_version(uuid, date) CASCADE;
DROP FUNCTION IF EXISTS can_edit_sheet(daily_sheets) CASCADE;

-- ============================================================================
-- STEP 3: Add item_name columns to line tables (if not exists)
-- ============================================================================

-- Pastry lines
ALTER TABLE pastry_lines ADD COLUMN IF NOT EXISTS item_name text;

-- Yoghurt container lines
ALTER TABLE yoghurt_container_lines ADD COLUMN IF NOT EXISTS item_name text;

-- Yoghurt refill lines
ALTER TABLE yoghurt_refill_lines ADD COLUMN IF NOT EXISTS item_name text;

-- Yoghurt non-container
ALTER TABLE yoghurt_non_container ADD COLUMN IF NOT EXISTS item_name text;

-- Material lines
ALTER TABLE material_lines ADD COLUMN IF NOT EXISTS item_name text;

-- ============================================================================
-- STEP 4: Populate item_name from items table
-- ============================================================================

UPDATE pastry_lines pl
SET item_name = i.name
FROM items i
WHERE pl.item_id = i.id AND pl.item_name IS NULL;

UPDATE yoghurt_container_lines yc
SET item_name = i.name
FROM items i
WHERE yc.item_id = i.id AND yc.item_name IS NULL;

UPDATE yoghurt_refill_lines yr
SET item_name = i.name
FROM items i
WHERE yr.item_id = i.id AND yr.item_name IS NULL;

UPDATE yoghurt_non_container ync
SET item_name = i.name
FROM items i
WHERE ync.item_id = i.id AND ync.item_name IS NULL;

UPDATE material_lines ml
SET item_name = i.name
FROM items i
WHERE ml.item_id = i.id AND ml.item_name IS NULL;

-- ============================================================================
-- STEP 5: Add unit_price and volume_factor to items table (for simpler pricing)
-- ============================================================================

ALTER TABLE items ADD COLUMN IF NOT EXISTS unit_price numeric(12,2) NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS volume_factor numeric(12,4) NOT NULL DEFAULT 1;

-- Populate from latest item_versions
UPDATE items i
SET 
  unit_price = COALESCE(iv.unit_price, 0),
  volume_factor = COALESCE(iv.volume_factor, 1)
FROM (
  SELECT DISTINCT ON (item_id) item_id, unit_price, volume_factor
  FROM item_versions
  ORDER BY item_id, effective_from DESC
) iv
WHERE i.id = iv.item_id;

-- ============================================================================
-- STEP 6: Drop old RLS policies and create new ones
-- ============================================================================

-- Drop old policies (ignore errors if they don't exist)
DROP POLICY IF EXISTS "branches_supervisor_all" ON branches;
DROP POLICY IF EXISTS "branches_branch_user" ON branches;
DROP POLICY IF EXISTS "user_profile_self" ON user_profiles;
DROP POLICY IF EXISTS "sheets_select_branch" ON daily_sheets;
DROP POLICY IF EXISTS "sheets_select_supervisor" ON daily_sheets;
DROP POLICY IF EXISTS "sheets_update_branch_user" ON daily_sheets;
DROP POLICY IF EXISTS "sheets_update_supervisor" ON daily_sheets;
DROP POLICY IF EXISTS "pastry_select_branch" ON pastry_lines;
DROP POLICY IF EXISTS "pastry_select_supervisor" ON pastry_lines;
DROP POLICY IF EXISTS "pastry_write_branch" ON pastry_lines;
DROP POLICY IF EXISTS "pastry_write_branch_update" ON pastry_lines;
DROP POLICY IF EXISTS "pastry_supervisor_all" ON pastry_lines;

-- Drop the old view
DROP VIEW IF EXISTS current_profile;

-- Create new view
CREATE OR REPLACE VIEW current_profile AS
SELECT * FROM user_profiles WHERE user_id = auth.uid();

-- Enable RLS on items table
ALTER TABLE items ENABLE ROW LEVEL SECURITY;

-- Branches policies (everyone can read)
CREATE POLICY "branches_select_all" ON branches
FOR SELECT USING (true);

-- Items policies (everyone can read)
CREATE POLICY "items_select_all" ON items
FOR SELECT USING (true);

-- User profile access (self)
CREATE POLICY "user_profile_self" ON user_profiles
FOR SELECT USING (user_id = auth.uid());

-- Daily sheets policies
CREATE POLICY "sheets_select_branch" ON daily_sheets
FOR SELECT USING (branch_id = (SELECT branch_id FROM current_profile WHERE role = 'branch_user'));

CREATE POLICY "sheets_select_supervisor" ON daily_sheets
FOR SELECT USING (EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor'));

CREATE POLICY "sheets_insert" ON daily_sheets
FOR INSERT WITH CHECK (
  branch_id = (SELECT branch_id FROM current_profile) 
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

CREATE POLICY "sheets_update" ON daily_sheets
FOR UPDATE USING (
  (branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
) WITH CHECK (
  (branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Pastry lines policies
CREATE POLICY "pastry_select" ON pastry_lines
FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

CREATE POLICY "pastry_insert" ON pastry_lines
FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

CREATE POLICY "pastry_update" ON pastry_lines
FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

CREATE POLICY "pastry_delete" ON pastry_lines
FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Yoghurt headers policies
CREATE POLICY "yh_select" ON yoghurt_headers FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yh_insert" ON yoghurt_headers FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yh_update" ON yoghurt_headers FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Yoghurt container lines policies
CREATE POLICY "yc_select" ON yoghurt_container_lines FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yc_insert" ON yoghurt_container_lines FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yc_update" ON yoghurt_container_lines FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yc_delete" ON yoghurt_container_lines FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Yoghurt refill lines policies
CREATE POLICY "yr_select" ON yoghurt_refill_lines FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yr_insert" ON yoghurt_refill_lines FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yr_update" ON yoghurt_refill_lines FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yr_delete" ON yoghurt_refill_lines FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Yoghurt non-container policies
CREATE POLICY "ync_select" ON yoghurt_non_container FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "ync_insert" ON yoghurt_non_container FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "ync_update" ON yoghurt_non_container FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "ync_delete" ON yoghurt_non_container FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Yoghurt section B policies
CREATE POLICY "yb_select" ON yoghurt_section_b_income FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yb_insert" ON yoghurt_section_b_income FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yb_update" ON yoghurt_section_b_income FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "yb_delete" ON yoghurt_section_b_income FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Material lines policies
CREATE POLICY "mat_select" ON material_lines FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "mat_insert" ON material_lines FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "mat_update" ON material_lines FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "mat_delete" ON material_lines FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Currency notes policies
CREATE POLICY "cn_select" ON currency_notes FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "cn_insert" ON currency_notes FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "cn_update" ON currency_notes FOR UPDATE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "cn_delete" ON currency_notes FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Staff attendance policies
CREATE POLICY "staff_select" ON staff_attendance FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "staff_insert" ON staff_attendance FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "staff_delete" ON staff_attendance FOR DELETE USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile) AND NOT locked)
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- Extra expenses policies
CREATE POLICY "exp_select" ON extra_expenses FOR SELECT USING (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);
CREATE POLICY "exp_insert" ON extra_expenses FOR INSERT WITH CHECK (
  sheet_id IN (SELECT id FROM daily_sheets WHERE branch_id = (SELECT branch_id FROM current_profile))
  OR EXISTS (SELECT 1 FROM current_profile WHERE role = 'supervisor')
);

-- ============================================================================
-- STEP 7: Update the seed_sheet_lines function to include item_name
-- ============================================================================

CREATE OR REPLACE FUNCTION seed_sheet_lines(p_sheet_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  s daily_sheets;
BEGIN
  SELECT * INTO s FROM daily_sheets WHERE id = p_sheet_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sheet % not found', p_sheet_id;
  END IF;

  -- Pastries
  INSERT INTO pastry_lines (sheet_id, item_id, item_name, unit_price)
  SELECT p_sheet_id, i.id, i.name, i.unit_price
  FROM items i
  WHERE i.category = 'pastry'
    AND NOT EXISTS (
      SELECT 1 FROM pastry_lines pl
      WHERE pl.sheet_id = p_sheet_id AND pl.item_id = i.id
    );

  -- Yoghurt containers
  INSERT INTO yoghurt_container_lines (sheet_id, item_id, item_name, unit_price, volume_factor)
  SELECT p_sheet_id, i.id, i.name, i.unit_price, i.volume_factor
  FROM items i
  WHERE i.category = 'yoghurt_container'
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_container_lines yc
      WHERE yc.sheet_id = p_sheet_id AND yc.item_id = i.id
    );

  -- Yoghurt refills
  INSERT INTO yoghurt_refill_lines (sheet_id, item_id, item_name, unit_price, volume_factor)
  SELECT p_sheet_id, i.id, i.name, i.unit_price, i.volume_factor
  FROM items i
  WHERE i.category = 'yoghurt_refill'
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_refill_lines yr
      WHERE yr.sheet_id = p_sheet_id AND yr.item_id = i.id
    );

  -- Yoghurt non-container (one row)
  INSERT INTO yoghurt_non_container (sheet_id, item_id, item_name, unit_price)
  SELECT p_sheet_id, i.id, i.name, i.unit_price
  FROM items i
  WHERE i.category = 'yoghurt_non_container'
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_non_container ync
      WHERE ync.sheet_id = p_sheet_id
    )
  LIMIT 1;

  -- Section B income rows
  INSERT INTO yoghurt_section_b_income (sheet_id, source, item_id)
  VALUES (p_sheet_id, 'pastries', null)
  ON CONFLICT DO NOTHING;

  INSERT INTO yoghurt_section_b_income (sheet_id, source, item_id, unit_price)
  SELECT p_sheet_id, 'smoothies', i.id, i.unit_price
  FROM items i
  WHERE i.code = 'YOG_SMOOTHIE'
  ON CONFLICT DO NOTHING;

  INSERT INTO yoghurt_section_b_income (sheet_id, source, item_id, unit_price)
  SELECT p_sheet_id, 'water', i.id, i.unit_price
  FROM items i
  WHERE i.code = 'YOG_WATER'
  ON CONFLICT DO NOTHING;

  -- Materials
  INSERT INTO material_lines (sheet_id, item_id, item_name)
  SELECT p_sheet_id, i.id, i.name
  FROM items i
  WHERE i.category = 'material'
    AND NOT EXISTS (
      SELECT 1 FROM material_lines m
      WHERE m.sheet_id = p_sheet_id AND m.item_id = i.id
    );

  -- Currency notes
  INSERT INTO currency_notes (sheet_id, denomination)
  VALUES
    (p_sheet_id, 200),
    (p_sheet_id, 100),
    (p_sheet_id, 50),
    (p_sheet_id, 20),
    (p_sheet_id, 10),
    (p_sheet_id, 5),
    (p_sheet_id, 1)
  ON CONFLICT DO NOTHING;

  -- Yoghurt header
  INSERT INTO yoghurt_headers (sheet_id)
  VALUES (p_sheet_id)
  ON CONFLICT (sheet_id) DO NOTHING;
END;
$$;

-- ============================================================================
-- STEP 8: Drop unused tables/types (optional - keep for reference)
-- ============================================================================

-- Optionally drop audit_logs and item_versions if not needed
-- DROP TABLE IF EXISTS audit_logs CASCADE;
-- DROP TABLE IF EXISTS item_versions CASCADE;
-- DROP TYPE IF EXISTS audit_action CASCADE;

-- ============================================================================
-- DONE! The database is now ready for frontend-calculation mode.
-- ============================================================================

SELECT 'Migration completed successfully!' AS status;
