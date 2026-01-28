-- ============================================================================
-- Add received_from_branch_id to material_lines
-- ============================================================================
-- This migration adds the received_from_branch_id column to track which branch
-- materials were received from
-- ============================================================================

-- Add received_from_branch_id column to material_lines
ALTER TABLE material_lines 
ADD COLUMN IF NOT EXISTS received_from_branch_id uuid REFERENCES branches(id);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_material_lines_received_from_branch 
ON material_lines(received_from_branch_id);
