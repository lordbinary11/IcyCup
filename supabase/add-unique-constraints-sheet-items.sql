-- ============================================================================
-- Add Unique Constraints to Prevent Duplicate Items on Sheets
-- ============================================================================
-- This migration adds unique constraints to ensure each item appears only
-- once per sheet, preventing duplicates when items are added or unarchived
-- ============================================================================

-- First, remove any existing duplicates before adding constraints
-- Keep only the first occurrence of each (sheet_id, item_id) pair

-- Remove duplicate pastry lines
DELETE FROM pastry_lines a
USING pastry_lines b
WHERE a.id > b.id
  AND a.sheet_id = b.sheet_id
  AND a.item_id = b.item_id;

-- Remove duplicate yoghurt container lines
DELETE FROM yoghurt_container_lines a
USING yoghurt_container_lines b
WHERE a.id > b.id
  AND a.sheet_id = b.sheet_id
  AND a.item_id = b.item_id;

-- Remove duplicate yoghurt refill lines
DELETE FROM yoghurt_refill_lines a
USING yoghurt_refill_lines b
WHERE a.id > b.id
  AND a.sheet_id = b.sheet_id
  AND a.item_id = b.item_id;

-- Remove duplicate yoghurt non-container lines
DELETE FROM yoghurt_non_container a
USING yoghurt_non_container b
WHERE a.id > b.id
  AND a.sheet_id = b.sheet_id
  AND a.item_id = b.item_id;

-- Remove duplicate material lines
DELETE FROM material_lines a
USING material_lines b
WHERE a.id > b.id
  AND a.sheet_id = b.sheet_id
  AND a.item_id = b.item_id;

-- Now add unique constraints to prevent future duplicates

ALTER TABLE pastry_lines
ADD CONSTRAINT pastry_lines_sheet_item_unique 
UNIQUE (sheet_id, item_id);

ALTER TABLE yoghurt_container_lines
ADD CONSTRAINT yoghurt_container_lines_sheet_item_unique 
UNIQUE (sheet_id, item_id);

ALTER TABLE yoghurt_refill_lines
ADD CONSTRAINT yoghurt_refill_lines_sheet_item_unique 
UNIQUE (sheet_id, item_id);

ALTER TABLE yoghurt_non_container
ADD CONSTRAINT yoghurt_non_container_sheet_item_unique 
UNIQUE (sheet_id, item_id);

ALTER TABLE material_lines
ADD CONSTRAINT material_lines_sheet_item_unique 
UNIQUE (sheet_id, item_id);
