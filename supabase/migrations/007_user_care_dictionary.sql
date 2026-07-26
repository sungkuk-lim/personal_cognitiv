-- 사용자·기관별 방문간호 사전 (병원·진료과·STT 보정)

CREATE TABLE IF NOT EXISTS user_care_dictionary (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  hospitals TEXT[] NOT NULL DEFAULT '{}',
  departments TEXT[] NOT NULL DEFAULT '{}',
  patient_names TEXT[] NOT NULL DEFAULT '{}',
  stt_typo_map JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_care_dictionary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "care_dict_select_own" ON user_care_dictionary;
DROP POLICY IF EXISTS "care_dict_upsert_own" ON user_care_dictionary;

CREATE POLICY "care_dict_select_own" ON user_care_dictionary
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "care_dict_upsert_own" ON user_care_dictionary
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
