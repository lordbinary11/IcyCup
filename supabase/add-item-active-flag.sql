-- ============================================================================
-- Add is_active Flag to Items Table
-- ============================================================================
-- This migration adds an is_active boolean column to the items table to allow
-- items to be deactivated instead of deleted. Inactive items won't appear on
-- new sheets but will remain in historical sheets.
-- ============================================================================

-- Add is_active column (defaults to true for existing items)
ALTER TABLE items
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- Create index for filtering active items
CREATE INDEX IF NOT EXISTS idx_items_active ON items(is_active);

-- Update seed_sheet_lines function to only include active items
CREATE OR REPLACE FUNCTION seed_sheet_lines(p_sheet_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  s daily_sheets;
BEGIN
  SELECT * INTO s FROM daily_sheets WHERE id = p_sheet_id;
  IF NOT found THEN
    RAISE EXCEPTION 'Sheet % not found', p_sheet_id;
  END IF;

  -- Pastries (only active items)
  INSERT INTO pastry_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'pastry'
    AND i.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM pastry_lines pl
      WHERE pl.sheet_id = p_sheet_id AND pl.item_id = i.id
    );

  -- Yoghurt containers (only active items)
  INSERT INTO yoghurt_container_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'yoghurt_container'
    AND i.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_container_lines yc
      WHERE yc.sheet_id = p_sheet_id AND yc.item_id = i.id
    );

  -- Yoghurt refills (only active items)
  INSERT INTO yoghurt_refill_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'yoghurt_refill'
    AND i.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_refill_lines yr
      WHERE yr.sheet_id = p_sheet_id AND yr.item_id = i.id
    );

  -- Yoghurt non-container (only active items)
  INSERT INTO yoghurt_non_container (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'yoghurt_non_container'
    AND i.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_non_container ync
      WHERE ync.sheet_id = p_sheet_id AND ync.item_id = i.id
    );

  -- Material lines (only active items)
  INSERT INTO material_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'material'
    AND i.is_active = true
    AND NOT EXISTS (
      SELECT 1 FROM material_lines ml
      WHERE ml.sheet_id = p_sheet_id AND ml.item_id = i.id
    );

  -- Section B income rows
  INSERT INTO yoghurt_section_b_income (sheet_id, source, item_id)
  VALUES (p_sheet_id, 'pastries', null)
  ON CONFLICT DO NOTHING;

  INSERT INTO yoghurt_section_b_income (sheet_id, source, item_id)
  SELECT p_sheet_id, 'smoothies', i.id
  FROM items i
  WHERE i.code = 'YOG_SMOOTHIE'
  LIMIT 1
  ON CONFLICT DO NOTHING;

  INSERT INTO yoghurt_section_b_income (sheet_id, source, item_id)
  SELECT p_sheet_id, 'water', i.id
  FROM items i
  WHERE i.code = 'YOG_WATER'
  LIMIT 1
  ON CONFLICT DO NOTHING;

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

END;
$$;
