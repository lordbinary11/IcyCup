-- ============================================================================
-- Fix Existing Sheet Lines to Use Correct Item Prices
-- ============================================================================
-- This migration updates all existing sheet lines to populate item_version_id
-- and unit_price based on the sheet date and item versions
-- ============================================================================

-- Update pastry_lines
UPDATE pastry_lines pl
SET 
  item_version_id = (
    SELECT iv.id
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = pl.sheet_id
    WHERE iv.item_id = pl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = pl.sheet_id
    WHERE iv.item_id = pl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE pl.item_version_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = pl.sheet_id
    WHERE iv.item_id = pl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
  );

-- Update yoghurt_container_lines
UPDATE yoghurt_container_lines ycl
SET 
  item_version_id = (
    SELECT iv.id
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ycl.sheet_id
    WHERE iv.item_id = ycl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ycl.sheet_id
    WHERE iv.item_id = ycl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  volume_factor = (
    SELECT iv.volume_factor
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ycl.sheet_id
    WHERE iv.item_id = ycl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE ycl.item_version_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ycl.sheet_id
    WHERE iv.item_id = ycl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
  );

-- Update yoghurt_refill_lines
UPDATE yoghurt_refill_lines yrl
SET 
  item_version_id = (
    SELECT iv.id
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = yrl.sheet_id
    WHERE iv.item_id = yrl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = yrl.sheet_id
    WHERE iv.item_id = yrl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  volume_factor = (
    SELECT iv.volume_factor
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = yrl.sheet_id
    WHERE iv.item_id = yrl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE yrl.item_version_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = yrl.sheet_id
    WHERE iv.item_id = yrl.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
  );

-- Update yoghurt_non_container
UPDATE yoghurt_non_container ync
SET 
  item_version_id = (
    SELECT iv.id
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ync.sheet_id
    WHERE iv.item_id = ync.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ync.sheet_id
    WHERE iv.item_id = ync.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE ync.item_version_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ync.sheet_id
    WHERE iv.item_id = ync.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
  );

-- Update yoghurt_section_b_income (only for items with item_id)
UPDATE yoghurt_section_b_income ybi
SET 
  item_version_id = (
    SELECT iv.id
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ybi.sheet_id
    WHERE iv.item_id = ybi.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ybi.sheet_id
    WHERE iv.item_id = ybi.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE ybi.item_id IS NOT NULL
  AND ybi.item_version_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM item_versions iv
    JOIN daily_sheets ds ON ds.id = ybi.sheet_id
    WHERE iv.item_id = ybi.item_id
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
  );

-- Recalculate amounts for pastry_lines
UPDATE pastry_lines
SET amount = qty_sold * unit_price
WHERE item_version_id IS NOT NULL;

-- Recalculate income for yoghurt_container_lines
UPDATE yoghurt_container_lines
SET 
  volume_sold = volume_factor * qty_sold,
  income = qty_sold * unit_price
WHERE item_version_id IS NOT NULL;

-- Recalculate income for yoghurt_refill_lines
UPDATE yoghurt_refill_lines
SET 
  volume_sold = volume_factor * qty_sold,
  income = qty_sold * unit_price
WHERE item_version_id IS NOT NULL;

-- Recalculate income for yoghurt_non_container
UPDATE yoghurt_non_container
SET income = volume_sold * unit_price
WHERE item_version_id IS NOT NULL;

-- Recalculate income for yoghurt_section_b_income
UPDATE yoghurt_section_b_income
SET income = qty_sold * unit_price
WHERE item_version_id IS NOT NULL
  AND qty_sold IS NOT NULL
  AND unit_price IS NOT NULL;
