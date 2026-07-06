-- Google Play / GDPR: 앱 내 계정·데이터 삭제 (인증 사용자 본인만).
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  uid uuid := auth.uid();
  deleted_memories int;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  DELETE FROM memories WHERE user_id = uid;
  GET DIAGNOSTICS deleted_memories = ROW_COUNT;

  DELETE FROM ai_usage_monthly WHERE user_id = uid;
  DELETE FROM user_subscriptions WHERE user_id = uid;

  RETURN jsonb_build_object(
    'ok', true,
    'memories_deleted', deleted_memories
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
