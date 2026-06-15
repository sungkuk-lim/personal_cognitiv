-- Remove legacy permissive policies that bypass user isolation
DROP POLICY IF EXISTS "memories_full_access" ON memories;
DROP POLICY IF EXISTS "Master Policy" ON memories;
