-- 클라이언트(구매 직후)가 본인 Pro 상태를 Supabase에 반영 — 웹훅 지연 대비.
-- auth.uid()만 갱신 가능. service role 웹훅(upsert_user_subscription)과 병행.

CREATE OR REPLACE FUNCTION sync_own_pro_entitlement(
  p_status TEXT,
  p_expires_at TIMESTAMPTZ DEFAULT NULL,
  p_product_id TEXT DEFAULT NULL,
  p_store TEXT DEFAULT 'play'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid UUID := auth.uid();
  next_tier TEXT;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF p_status NOT IN ('active', 'trialing', 'inactive', 'expired', 'cancelled') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  next_tier := CASE
    WHEN p_status IN ('active', 'trialing') THEN 'pro'
    ELSE 'free'
  END;

  INSERT INTO user_subscriptions (user_id, tier, status, expires_at, store, product_id, updated_at)
  VALUES (uid, next_tier, p_status, p_expires_at, p_store, p_product_id, now())
  ON CONFLICT (user_id) DO UPDATE SET
    tier = EXCLUDED.tier,
    status = EXCLUDED.status,
    expires_at = EXCLUDED.expires_at,
    store = EXCLUDED.store,
    product_id = EXCLUDED.product_id,
    updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION sync_own_pro_entitlement(TEXT, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
