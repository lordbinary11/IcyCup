-- ============================================================================
-- Create get_active_item_version Function
-- ============================================================================
-- This function retrieves the active item version for a given item on a
-- specific date, used by triggers to populate prices automatically
-- ============================================================================

CREATE OR REPLACE FUNCTION get_active_item_version(p_item uuid, p_date date)
RETURNS item_versions AS $$
  SELECT *
  FROM item_versions
  WHERE item_id = p_item
    AND effective_from <= p_date
    AND (effective_to IS NULL OR effective_to >= p_date)
  ORDER BY effective_from DESC
  LIMIT 1;
$$ LANGUAGE sql STABLE;
