-- SaaS: 구독 상태 + AI 월간 쿼터

CREATE TABLE IF NOT EXISTS user_subscriptions (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  status TEXT NOT NULL DEFAULT 'inactive' CHECK (
    status IN ('inactive', 'active', 'trialing', 'canceled', 'expired')
  ),
  expires_at TIMESTAMPTZ,
  store TEXT CHECK (store IN ('play', 'appstore', 'manual', 'revenuecat')),
  product_id TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS user_subscriptions_status_idx ON user_subscriptions (status);

ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_subscriptions_select_own" ON user_subscriptions;
CREATE POLICY "user_subscriptions_select_own" ON user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS ai_usage_monthly (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month_key TEXT NOT NULL,
  chat_count INT NOT NULL DEFAULT 0,
  embedding_count INT NOT NULL DEFAULT 0,
  vision_count INT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, month_key)
);

ALTER TABLE ai_usage_monthly ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ai_usage_monthly_select_own" ON ai_usage_monthly;
CREATE POLICY "ai_usage_monthly_select_own" ON ai_usage_monthly
  FOR SELECT USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION consume_ai_quota(p_action TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_tier TEXT;
  v_status TEXT;
  v_expires TIMESTAMPTZ;
  v_month TEXT := to_char(timezone('UTC', now()), 'YYYY-MM');
  v_chat INT;
  v_emb INT;
  v_vis INT;
  v_limit INT;
  v_count INT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'code', 'unauthorized');
  END IF;

  SELECT tier, status, expires_at
  INTO v_tier, v_status, v_expires
  FROM user_subscriptions
  WHERE user_id = v_uid;

  IF NOT FOUND THEN
    v_tier := 'free';
    v_status := 'inactive';
  END IF;

  IF v_tier <> 'pro'
     OR v_status NOT IN ('active', 'trialing')
     OR (v_expires IS NOT NULL AND v_expires < now()) THEN
    RETURN jsonb_build_object('allowed', false, 'code', 'subscription_required');
  END IF;

  INSERT INTO ai_usage_monthly (user_id, month_key)
  VALUES (v_uid, v_month)
  ON CONFLICT (user_id, month_key) DO NOTHING;

  SELECT chat_count, embedding_count, vision_count
  INTO v_chat, v_emb, v_vis
  FROM ai_usage_monthly
  WHERE user_id = v_uid AND month_key = v_month;

  IF p_action = 'chat' THEN
    v_limit := 500;
    v_count := v_chat;
  ELSIF p_action = 'embedding' THEN
    v_limit := 300;
    v_count := v_emb;
  ELSIF p_action = 'vision' THEN
    v_limit := 100;
    v_count := v_vis;
  ELSE
    RETURN jsonb_build_object('allowed', false, 'code', 'invalid_action');
  END IF;

  IF v_count >= v_limit THEN
    RETURN jsonb_build_object(
      'allowed', false,
      'code', 'quota_exceeded',
      'limit', v_limit,
      'used', v_count,
      'action', p_action
    );
  END IF;

  UPDATE ai_usage_monthly
  SET
    chat_count = chat_count + CASE WHEN p_action = 'chat' THEN 1 ELSE 0 END,
    embedding_count = embedding_count + CASE WHEN p_action = 'embedding' THEN 1 ELSE 0 END,
    vision_count = vision_count + CASE WHEN p_action = 'vision' THEN 1 ELSE 0 END
  WHERE user_id = v_uid AND month_key = v_month;

  RETURN jsonb_build_object(
    'allowed', true,
    'remaining', v_limit - v_count - 1,
    'limit', v_limit,
    'action', p_action
  );
END;
$$;

GRANT EXECUTE ON FUNCTION consume_ai_quota(TEXT) TO authenticated;

-- RevenueCat 웹훅·관리용 (service role만 호출)
CREATE OR REPLACE FUNCTION upsert_user_subscription(
  p_user_id UUID,
  p_tier TEXT,
  p_status TEXT,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_store TEXT DEFAULT 'revenuecat',
  p_product_id TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_subscriptions (user_id, tier, status, expires_at, store, product_id, updated_at)
  VALUES (p_user_id, p_tier, p_status, p_expires_at, p_store, p_product_id, now())
  ON CONFLICT (user_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    status = EXCLUDED.status,
    expires_at = EXCLUDED.expires_at,
    store = EXCLUDED.store,
    product_id = EXCLUDED.product_id,
    updated_at = now();
END;
$$;
