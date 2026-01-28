-- ============================================================================
-- Fix Section B Prices for All Existing Sheets
-- ============================================================================
-- This migration updates all existing yoghurt_section_b_income rows to populate
-- item_id, item_version_id, and unit_price for smoothies and water items
-- ============================================================================

-- Fix all smoothies rows across all sheets
UPDATE yoghurt_section_b_income yb
SET 
  item_id = (SELECT id FROM items WHERE code = 'YOG_SMOOTHIE' LIMIT 1),
  item_version_id = (
    SELECT iv.id 
    FROM items i
    JOIN item_versions iv ON iv.item_id = i.id
    JOIN daily_sheets ds ON ds.id = yb.sheet_id
    WHERE i.code = 'YOG_SMOOTHIE'
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price 
    FROM items i
    JOIN item_versions iv ON iv.item_id = i.id
    JOIN daily_sheets ds ON ds.id = yb.sheet_id
    WHERE i.code = 'YOG_SMOOTHIE'
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE yb.source = 'smoothies'
  AND yb.item_id IS NULL
  AND EXISTS (SELECT 1 FROM items WHERE code = 'YOG_SMOOTHIE');

-- Fix all water rows across all sheets
UPDATE yoghurt_section_b_income yb
SET 
  item_id = (SELECT id FROM items WHERE code = 'YOG_WATER' LIMIT 1),
  item_version_id = (
    SELECT iv.id 
    FROM items i
    JOIN item_versions iv ON iv.item_id = i.id
    JOIN daily_sheets ds ON ds.id = yb.sheet_id
    WHERE i.code = 'YOG_WATER'
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  ),
  unit_price = (
    SELECT iv.unit_price 
    FROM items i
    JOIN item_versions iv ON iv.item_id = i.id
    JOIN daily_sheets ds ON ds.id = yb.sheet_id
    WHERE i.code = 'YOG_WATER'
      AND iv.effective_from <= ds.sheet_date
      AND (iv.effective_to IS NULL OR iv.effective_to >= ds.sheet_date)
    ORDER BY iv.effective_from DESC
    LIMIT 1
  )
WHERE yb.source = 'water'
  AND yb.item_id IS NULL
  AND EXISTS (SELECT 1 FROM items WHERE code = 'YOG_WATER');
