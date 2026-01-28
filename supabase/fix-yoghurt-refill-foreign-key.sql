-- ============================================================================
-- Fix Yoghurt Refill Lines Foreign Key Relationship
-- ============================================================================
-- The yoghurt_refill_lines table was created with LIKE which doesn't properly
-- register the foreign key relationship with PostgREST. This fixes it.
-- ============================================================================

-- Drop the existing foreign key constraint if it exists
ALTER TABLE yoghurt_refill_lines
DROP CONSTRAINT IF EXISTS yoghurt_refill_lines_item_id_fkey;

-- Re-add the foreign key constraint explicitly
ALTER TABLE yoghurt_refill_lines
ADD CONSTRAINT yoghurt_refill_lines_item_id_fkey
FOREIGN KEY (item_id) REFERENCES items(id);

-- Refresh the PostgREST schema cache
NOTIFY pgrst, 'reload schema';
