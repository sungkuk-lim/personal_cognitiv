-- Fix: 기존 match_memories 시그니처/반환형이 다를 때 마이그레이션 실패 방지

ALTER TABLE memories ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

CREATE INDEX IF NOT EXISTS memories_user_id_idx ON memories(user_id);

ALTER TABLE memories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "memories_select_own" ON memories;
DROP POLICY IF EXISTS "memories_insert_own" ON memories;
DROP POLICY IF EXISTS "memories_update_own" ON memories;
DROP POLICY IF EXISTS "memories_delete_own" ON memories;

CREATE POLICY "memories_select_own" ON memories
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "memories_insert_own" ON memories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "memories_update_own" ON memories
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "memories_delete_own" ON memories
  FOR DELETE USING (auth.uid() = user_id);

DROP FUNCTION IF EXISTS match_memories(vector, double precision, integer);
DROP FUNCTION IF EXISTS match_memories(vector, float, int);

CREATE OR REPLACE FUNCTION match_memories(
  query_embedding vector(1536),
  match_threshold float,
  match_count int
)
RETURNS SETOF memories
LANGUAGE sql STABLE
AS $$
  SELECT *
  FROM memories
  WHERE user_id = auth.uid()
    AND embedding IS NOT NULL
    AND 1 - (embedding <=> query_embedding) > match_threshold
  ORDER BY embedding <=> query_embedding
  LIMIT match_count;
$$;

-- Remove legacy permissive policies that bypass user isolation
DROP POLICY IF EXISTS "memories_full_access" ON memories;
DROP POLICY IF EXISTS "Master Policy" ON memories;
