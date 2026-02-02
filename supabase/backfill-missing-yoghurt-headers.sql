-- ============================================================================
-- Backfill Missing Yoghurt Headers
-- ============================================================================
-- Create yoghurt_headers rows for any sheets that are missing them
-- ============================================================================

-- Insert yoghurt headers for all sheets that don't have one
INSERT INTO yoghurt_headers (sheet_id, opening_stock, stock_received, total_stock, closing_stock)
SELECT 
  ds.id as sheet_id,
  0 as opening_stock,
  0 as stock_received,
  0 as total_stock,
  0 as closing_stock
FROM daily_sheets ds
WHERE NOT EXISTS (
  SELECT 1 FROM yoghurt_headers yh WHERE yh.sheet_id = ds.id
)
ON CONFLICT (sheet_id) DO NOTHING;
