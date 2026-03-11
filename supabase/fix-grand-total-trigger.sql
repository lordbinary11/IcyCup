-- Fix grand total calculation with database trigger
-- This ensures grand_total is always calculated correctly regardless of frontend issues

CREATE OR REPLACE FUNCTION calculate_grand_total()
RETURNS TRIGGER AS $$
BEGIN
  -- Calculate grand total as sum of all income sources
  NEW.grand_total = COALESCE(NEW.yoghurt_section_a_total_income, 0) + COALESCE(NEW.yoghurt_section_b_total, 0);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trg_calculate_grand_total ON daily_sheets;

-- Create trigger to calculate grand total before insert/update
CREATE TRIGGER trg_calculate_grand_total
BEFORE INSERT OR UPDATE ON daily_sheets
FOR EACH ROW EXECUTE FUNCTION calculate_grand_total();

-- Update existing sheets with correct grand totals
UPDATE daily_sheets 
SET grand_total = 
                  COALESCE(yoghurt_section_a_total_income, 0) + 
                  COALESCE(yoghurt_section_b_total, 0)
WHERE grand_total IS NULL OR grand_total = 0;
