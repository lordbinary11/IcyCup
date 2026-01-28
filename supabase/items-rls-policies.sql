-- ============================================================================
-- RLS Policies for Items and Item Versions Management
-- ============================================================================
-- This migration adds RLS policies to allow supervisors to manage items
-- and item versions (prices with effective dates)
-- ============================================================================

-- Items table policies
-- Drop existing policies if they exist
DROP POLICY IF EXISTS "items_select_all" ON items;
DROP POLICY IF EXISTS "items_insert_supervisor" ON items;
DROP POLICY IF EXISTS "items_update_supervisor" ON items;
DROP POLICY IF EXISTS "items_delete_supervisor" ON items;

-- Everyone can read items
CREATE POLICY "items_select_all" ON items
FOR SELECT USING (true);

-- Only supervisors can insert new items
CREATE POLICY "items_insert_supervisor" ON items
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND role = 'supervisor'
  )
);

-- Only supervisors can update items
CREATE POLICY "items_update_supervisor" ON items
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND role = 'supervisor'
  )
);

-- Only supervisors can delete items
CREATE POLICY "items_delete_supervisor" ON items
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND role = 'supervisor'
  )
);

-- Item versions table policies
-- Enable RLS on item_versions if not already enabled
ALTER TABLE item_versions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "item_versions_select_all" ON item_versions;
DROP POLICY IF EXISTS "item_versions_insert_supervisor" ON item_versions;
DROP POLICY IF EXISTS "item_versions_update_supervisor" ON item_versions;
DROP POLICY IF EXISTS "item_versions_delete_supervisor" ON item_versions;

-- Everyone can read item versions
CREATE POLICY "item_versions_select_all" ON item_versions
FOR SELECT USING (true);

-- Only supervisors can insert new versions
CREATE POLICY "item_versions_insert_supervisor" ON item_versions
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND role = 'supervisor'
  )
);

-- Only supervisors can update versions
CREATE POLICY "item_versions_update_supervisor" ON item_versions
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND role = 'supervisor'
  )
);

-- Only supervisors can delete versions
CREATE POLICY "item_versions_delete_supervisor" ON item_versions
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid()
    AND role = 'supervisor'
  )
);
