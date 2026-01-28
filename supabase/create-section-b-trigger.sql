-- ============================================================================
-- Create yoghurt_section_b_biud Trigger
-- ============================================================================
-- This trigger automatically populates item_version_id and unit_price for
-- yoghurt section B income rows when they are inserted or updated
-- ============================================================================

CREATE OR REPLACE FUNCTION yoghurt_section_b_biud()
RETURNS trigger AS $$
DECLARE
  v item_versions;
  sdate date;
BEGIN
  SELECT sheet_date INTO sdate FROM daily_sheets WHERE id = new.sheet_id;
  
  -- Pastries row gets income from total_pastries_income
  IF new.source = 'pastries' THEN
    new.income := (SELECT total_pastries_income FROM daily_sheets WHERE id = new.sheet_id);
    new.unit_price := null;
    new.qty_sold := null;
    RETURN new;
  END IF;

  -- For smoothies and water, populate item_version_id and unit_price
  IF tg_op = 'INSERT' AND new.item_version_id IS NULL AND new.item_id IS NOT NULL THEN
    SELECT * INTO v FROM get_active_item_version(new.item_id, sdate);
    IF FOUND THEN
      new.item_version_id := v.id;
      new.unit_price := v.unit_price;
    END IF;
  END IF;

  -- Calculate income
  new.income := COALESCE(new.qty_sold, 0) * COALESCE(new.unit_price, 0);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS trg_yoghurt_section_b_biud ON yoghurt_section_b_income;

CREATE TRIGGER trg_yoghurt_section_b_biud
BEFORE INSERT OR UPDATE ON yoghurt_section_b_income
FOR EACH ROW EXECUTE PROCEDURE yoghurt_section_b_biud();
