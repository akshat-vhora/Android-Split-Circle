BEGIN;

CREATE OR REPLACE FUNCTION public.find_user_by_unique_id(p_unique_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_user public.users;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE lower(unique_id) = lower(trim(p_unique_id))
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'uid', v_user.uid,
    'display_name', v_user.display_name,
    'email', v_user.email,
    'unique_id', v_user.unique_id,
    'avatar_url', v_user.avatar_url,
    'upi_id', v_user.upi_id,
    'created_at', v_user.created_at,
    'updated_at', v_user.updated_at
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.find_user_by_unique_id(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_user_by_unique_id(text) TO authenticated;

COMMIT;
