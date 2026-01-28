-- ============================================================================
-- Refresh Sheet Items Function
-- ============================================================================
-- This function adds any missing items to a sheet and populates their prices
-- Call this when loading a sheet to ensure all active items appear
-- ============================================================================

CREATE OR REPLACE FUNCTION refresh_sheet_items(p_sheet_id uuid)
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

  -- Add missing pastry items (only if is_active column exists and is true)
  INSERT INTO pastry_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'pastry'
    AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'items' AND column_name = 'is_active')
         OR i.is_active = true)
    AND NOT EXISTS (
      SELECT 1 FROM pastry_lines pl
      WHERE pl.sheet_id = p_sheet_id AND pl.item_id = i.id
    );

  -- Add missing yoghurt container items
  INSERT INTO yoghurt_container_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'yoghurt_container'
    AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'items' AND column_name = 'is_active')
         OR i.is_active = true)
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_container_lines yc
      WHERE yc.sheet_id = p_sheet_id AND yc.item_id = i.id
    );

  -- Add missing yoghurt refill items
  INSERT INTO yoghurt_refill_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'yoghurt_refill'
    AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'items' AND column_name = 'is_active')
         OR i.is_active = true)
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_refill_lines yr
      WHERE yr.sheet_id = p_sheet_id AND yr.item_id = i.id
    );

  -- Add missing yoghurt non-container items
  INSERT INTO yoghurt_non_container (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'yoghurt_non_container'
    AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'items' AND column_name = 'is_active')
         OR i.is_active = true)
    AND NOT EXISTS (
      SELECT 1 FROM yoghurt_non_container ync
      WHERE ync.sheet_id = p_sheet_id AND ync.item_id = i.id
    );

  -- Add missing material items
  INSERT INTO material_lines (sheet_id, item_id)
  SELECT p_sheet_id, i.id
  FROM items i
  WHERE i.category = 'material'
    AND (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'items' AND column_name = 'is_active')
         OR i.is_active = true)
    AND NOT EXISTS (
      SELECT 1 FROM material_lines ml
      WHERE ml.sheet_id = p_sheet_id AND ml.item_id = i.id
    );

  -- Update pastry lines that have NULL item_version_id
  UPDATE pastry_lines pl
  SET 
    item_version_id = (
      SELECT iv.id
      FROM item_versions iv
      WHERE iv.item_id = pl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    ),
    unit_price = (
      SELECT iv.unit_price
      FROM item_versions iv
      WHERE iv.item_id = pl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    )
  WHERE pl.sheet_id = p_sheet_id
    AND pl.item_version_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM item_versions iv
      WHERE iv.item_id = pl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
    );

  -- Update yoghurt container lines that have NULL item_version_id
  UPDATE yoghurt_container_lines ycl
  SET 
    item_version_id = (
      SELECT iv.id
      FROM item_versions iv
      WHERE iv.item_id = ycl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    ),
    unit_price = (
      SELECT iv.unit_price
      FROM item_versions iv
      WHERE iv.item_id = ycl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    ),
    volume_factor = (
      SELECT iv.volume_factor
      FROM item_versions iv
      WHERE iv.item_id = ycl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    )
  WHERE ycl.sheet_id = p_sheet_id
    AND ycl.item_version_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM item_versions iv
      WHERE iv.item_id = ycl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
    );

  -- Update yoghurt refill lines that have NULL item_version_id
  UPDATE yoghurt_refill_lines yrl
  SET 
    item_version_id = (
      SELECT iv.id
      FROM item_versions iv
      WHERE iv.item_id = yrl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    ),
    unit_price = (
      SELECT iv.unit_price
      FROM item_versions iv
      WHERE iv.item_id = yrl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    ),
    volume_factor = (
      SELECT iv.volume_factor
      FROM item_versions iv
      WHERE iv.item_id = yrl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    )
  WHERE yrl.sheet_id = p_sheet_id
    AND yrl.item_version_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM item_versions iv
      WHERE iv.item_id = yrl.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
    );

  -- Update yoghurt non-container lines that have NULL item_version_id
  UPDATE yoghurt_non_container ync
  SET 
    item_version_id = (
      SELECT iv.id
      FROM item_versions iv
      WHERE iv.item_id = ync.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    ),
    unit_price = (
      SELECT iv.unit_price
      FROM item_versions iv
      WHERE iv.item_id = ync.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
      ORDER BY iv.effective_from DESC
      LIMIT 1
    )
  WHERE ync.sheet_id = p_sheet_id
    AND ync.item_version_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM item_versions iv
      WHERE iv.item_id = ync.item_id
        AND iv.effective_from <= s.sheet_date
        AND (iv.effective_to IS NULL OR iv.effective_to >= s.sheet_date)
    );

END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION refresh_sheet_items(uuid) TO authenticated;
