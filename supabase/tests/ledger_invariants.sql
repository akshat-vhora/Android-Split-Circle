BEGIN;

DO $$
DECLARE
  v_a uuid := '00000000-0000-4000-8000-0000000000a1';
  v_b uuid := '00000000-0000-4000-8000-0000000000b2';
  v_c uuid := '00000000-0000-4000-8000-0000000000c3';
  v_expense_one uuid := '10000000-0000-4000-8000-000000000001';
  v_expense_two uuid := '10000000-0000-4000-8000-000000000002';
  v_expense_two_id uuid;
  v_requested_at timestamptz;
BEGIN
  INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  VALUES
    (v_a, 'authenticated', 'authenticated', 'ledger-a@example.test', 'x', now(), now(), now()),
    (v_b, 'authenticated', 'authenticated', 'ledger-b@example.test', 'x', now(), now(), now()),
    (v_c, 'authenticated', 'authenticated', 'ledger-c@example.test', 'x', now(), now(), now())
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.users (uid, display_name, email, unique_id)
  VALUES
    (v_a, 'Ledger A', 'ledger-a@example.test', 'ledgera1'),
    (v_b, 'Ledger B', 'ledger-b@example.test', 'ledgerb1'),
    (v_c, 'Ledger C', 'ledger-c@example.test', 'ledgerc1')
  ON CONFLICT (uid) DO NOTHING;

  INSERT INTO public.friendships (user_id, friend_user_id)
  VALUES (v_a, v_b), (v_a, v_c)
  ON CONFLICT DO NOTHING;

  PERFORM set_config('request.jwt.claim.sub', v_a::text, true);

  PERFORM public.create_expense_with_balances(jsonb_build_object(
    'expense_id', v_expense_one::text,
    'title', 'single participant',
    'category', 'test',
    'total_amount', 100,
    'paid_by', v_a::text,
    'created_by', v_a::text,
    'split_type', 'equal',
    'splits', jsonb_build_object(v_a::text, jsonb_build_object('amount', 100)),
    'created_at', now()
  ));

  IF EXISTS (SELECT 1 FROM public.friend_balance_view) THEN
    RAISE EXCEPTION 'single participant expense created liability';
  END IF;

  PERFORM public.create_expense_with_balances(jsonb_build_object(
    'expense_id', v_expense_two::text,
    'title', 'three participant cents',
    'category', 'test',
    'total_amount', 100,
    'paid_by', v_a::text,
    'created_by', v_a::text,
    'split_type', 'custom',
    'splits', jsonb_build_object(
      v_a::text, jsonb_build_object('amount', 33.34),
      v_b::text, jsonb_build_object('amount', 33.33),
      v_c::text, jsonb_build_object('amount', 33.33)
    ),
    'created_at', now()
  ));

  IF (SELECT sum(share_amount) FROM public.expense_splits WHERE expense_id = v_expense_two) <> 100 THEN
    RAISE EXCEPTION 'split sum did not equal expense total';
  END IF;

  SELECT id INTO v_expense_two_id
  FROM public.expenses
  WHERE expense_id = v_expense_two;

  IF (SELECT amount FROM public.friend_balance_view WHERE friend_id = v_b) <> 33.33 THEN
    RAISE EXCEPTION 'unexpected pre-settlement balance';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_b::text, true);
  PERFORM public.request_settlement(v_expense_two_id::text);

  SELECT created_at INTO v_requested_at
  FROM public.settlements
  WHERE expense_id = v_expense_two_id
    AND payer_user_id = v_b
    AND status = 'requested';

  PERFORM public.request_settlement(v_expense_two_id::text);

  IF (
    SELECT created_at
    FROM public.settlements
    WHERE expense_id = v_expense_two_id
      AND payer_user_id = v_b
      AND status = 'requested'
  ) <> v_requested_at THEN
    RAISE EXCEPTION 'idempotent settlement request changed timestamp';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_a::text, true);
  PERFORM public.confirm_settlement(v_expense_two_id::text, v_b::text);
  PERFORM public.confirm_settlement(v_expense_two_id::text, v_b::text);

  IF (
    SELECT count(*)
    FROM public.settlements
    WHERE expense_id = v_expense_two_id
      AND payer_user_id = v_b
      AND status = 'confirmed'
  ) <> 1 THEN
    RAISE EXCEPTION 'confirm settlement was not idempotent';
  END IF;

  IF EXISTS (SELECT 1 FROM public.friend_balance_view WHERE friend_id = v_b) THEN
    RAISE EXCEPTION 'confirmed settlement left active balance';
  END IF;

  PERFORM public.delete_expense_with_balances(v_expense_two_id::text);

  IF NOT EXISTS (
    SELECT 1
    FROM public.settlements
    WHERE expense_id = v_expense_two_id
      AND status = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'soft delete removed settlement history';
  END IF;

  IF (
    WITH active_rows AS (
      SELECT e.paid_by AS user_id, s.share_amount AS amount
      FROM public.expenses e
      JOIN public.expense_splits s ON s.expense_id = e.id
      WHERE e.deleted_at IS NULL
        AND s.user_id <> e.paid_by
        AND NOT EXISTS (
          SELECT 1
          FROM public.settlements st
          WHERE st.expense_id = e.id
            AND st.payer_user_id = s.user_id
            AND st.receiver_user_id = e.paid_by
            AND st.status = 'confirmed'
        )
      UNION ALL
      SELECT s.user_id AS user_id, -s.share_amount AS amount
      FROM public.expenses e
      JOIN public.expense_splits s ON s.expense_id = e.id
      WHERE e.deleted_at IS NULL
        AND s.user_id <> e.paid_by
        AND NOT EXISTS (
          SELECT 1
          FROM public.settlements st
          WHERE st.expense_id = e.id
            AND st.payer_user_id = s.user_id
            AND st.receiver_user_id = e.paid_by
            AND st.status = 'confirmed'
        )
    )
    SELECT round(COALESCE(sum(amount), 0), 2) FROM active_rows
  ) <> 0 THEN
    RAISE EXCEPTION 'global net balance invariant failed';
  END IF;
END $$;

ROLLBACK;
