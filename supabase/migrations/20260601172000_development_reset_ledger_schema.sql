-- Development reset: destructive rebuild to the final ledger-first schema.
-- Existing public data is intentionally destroyed.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop obsolete views/materialized views.
DROP MATERIALIZED VIEW IF EXISTS public.dashboard_totals_mat_view CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.friend_balance_mat_view CASCADE;
DROP VIEW IF EXISTS public.expense_read_view CASCADE;
DROP VIEW IF EXISTS public.expense_ledger_history_view CASCADE;
DROP VIEW IF EXISTS public.dashboard_totals_admin_view CASCADE;
DROP VIEW IF EXISTS public.dashboard_totals_view CASCADE;
DROP VIEW IF EXISTS public.user_balance_view CASCADE;
DROP VIEW IF EXISTS public.friend_balance_view CASCADE;

-- Drop obsolete/final financial and support RPCs so only clean versions remain.
DROP FUNCTION IF EXISTS public.create_expense_with_balances(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.delete_expense_with_balances(text) CASCADE;
DROP FUNCTION IF EXISTS public.request_settlement(text, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.confirm_settlement(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.reject_settlement(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.remove_friend_secure(text) CASCADE;
DROP FUNCTION IF EXISTS public.add_friend_secure(text) CASCADE;
DROP FUNCTION IF EXISTS public.can_view_expense(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.validate_expense_split_sum() CASCADE;
DROP FUNCTION IF EXISTS public.validate_expense_total_split_sum() CASCADE;
DROP FUNCTION IF EXISTS public.validate_settlement_amount() CASCADE;
DROP FUNCTION IF EXISTS public.prevent_confirmed_settlement_mutation() CASCADE;
DROP FUNCTION IF EXISTS public.apply_friend_balance_delta(text, text, numeric, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.set_friend_balance_rpc(text, text, numeric) CASCADE;
DROP FUNCTION IF EXISTS public.set_friend_balance_rpc(text, text, numeric, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.delete_friend_balance_rpc(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.delete_friend_balance_rpc(text, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.adjust_user_totals_rpc(text, numeric, numeric) CASCADE;
DROP FUNCTION IF EXISTS public.update_user_totals_rpc(text) CASCADE;
DROP FUNCTION IF EXISTS public.update_preferred_currency(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.remove_friend_from_user(text, text) CASCADE;
DROP FUNCTION IF EXISTS public.add_friend_request(text, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.accept_friend_request(text, text, jsonb, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.insert_notification_rpc(jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.check_email_provider(text) CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;

-- Drop obsolete/final tables. CASCADE removes old policies/triggers/indexes/FKs.
DROP TABLE IF EXISTS public.friend_balances CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.ledger_migration_backup CASCADE;
DROP TABLE IF EXISTS public.settlements CASCADE;
DROP TABLE IF EXISTS public.expense_splits CASCADE;
DROP TABLE IF EXISTS public.expenses CASCADE;
DROP TABLE IF EXISTS public.friendships CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Storage object/bucket deletion must be done through the Storage API/CLI, not SQL.
DROP POLICY IF EXISTS "receipts_insert_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "receipts_select_public" ON storage.objects;
DROP POLICY IF EXISTS "receipts_select_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "receipts_update_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "receipts_delete_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "avatars_insert_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "avatars_select_public" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update_own_folder" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete_own_folder" ON storage.objects;

-- Core tables.
CREATE TABLE public.users (
  uid uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL CHECK (btrim(display_name) <> ''),
  email text NOT NULL UNIQUE CHECK (position('@' in email) > 1),
  unique_id text NOT NULL UNIQUE CHECK (btrim(unique_id) <> ''),
  avatar_url text,
  upi_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.friendships (
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  friend_user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_user_id),
  CONSTRAINT friendships_no_self CHECK (user_id <> friend_user_id)
);

CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid NOT NULL UNIQUE,
  title text NOT NULL CHECK (btrim(title) <> ''),
  description text,
  category text NOT NULL CHECK (btrim(category) <> ''),
  total_amount numeric(12,2) NOT NULL CHECK (total_amount > 0),
  paid_by uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  created_by uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  split_type text NOT NULL CHECK (split_type IN ('equal', 'custom', 'percentage', 'shares', 'subitem')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  deleted_by uuid REFERENCES public.users(uid) ON DELETE RESTRICT,
  CONSTRAINT expenses_deleted_by_requires_deleted_at CHECK (
    (deleted_at IS NULL AND deleted_by IS NULL)
    OR (deleted_at IS NOT NULL AND deleted_by IS NOT NULL)
  )
);

CREATE TABLE public.expense_splits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid NOT NULL REFERENCES public.expenses(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  share_amount numeric(12,2) NOT NULL CHECK (share_amount >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (expense_id, user_id)
);

CREATE TABLE public.settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid NOT NULL REFERENCES public.expenses(id) ON DELETE RESTRICT,
  payer_user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  receiver_user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  status text NOT NULL CHECK (status IN ('requested', 'confirmed', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  confirmed_at timestamptz,
  CONSTRAINT settlements_no_self CHECK (payer_user_id <> receiver_user_id),
  CONSTRAINT settlements_confirmed_at_status CHECK (
    (status = 'confirmed' AND confirmed_at IS NOT NULL)
    OR (status <> 'confirmed' AND confirmed_at IS NULL)
  )
);

-- Indexes.
CREATE UNIQUE INDEX friendships_reverse_pair_key
  ON public.friendships (LEAST(user_id, friend_user_id), GREATEST(user_id, friend_user_id));

CREATE INDEX idx_friendships_user ON public.friendships(user_id);
CREATE INDEX idx_friendships_friend ON public.friendships(friend_user_id);
CREATE INDEX idx_expenses_paid_by ON public.expenses(paid_by);
CREATE INDEX idx_expenses_created_by ON public.expenses(created_by);
CREATE INDEX idx_expenses_active_created_at ON public.expenses(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_expense_splits_expense ON public.expense_splits(expense_id);
CREATE INDEX idx_expense_splits_user ON public.expense_splits(user_id);
CREATE INDEX idx_settlements_expense ON public.settlements(expense_id);
CREATE INDEX idx_settlements_payer ON public.settlements(payer_user_id);
CREATE INDEX idx_settlements_receiver ON public.settlements(receiver_user_id);

CREATE UNIQUE INDEX settlements_one_requested
  ON public.settlements(expense_id, payer_user_id, receiver_user_id)
  WHERE status = 'requested';

CREATE UNIQUE INDEX settlements_one_confirmed
  ON public.settlements(expense_id, payer_user_id, receiver_user_id)
  WHERE status = 'confirmed';

-- Generic timestamp trigger.
CREATE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_expenses_updated_at
BEFORE UPDATE ON public.expenses
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- Ledger integrity triggers.
CREATE FUNCTION public.validate_expense_split_sum()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expense_id uuid := COALESCE(NEW.expense_id, OLD.expense_id);
  v_total numeric;
  v_split_total numeric;
BEGIN
  SELECT total_amount INTO v_total
  FROM public.expenses
  WHERE id = v_expense_id;

  SELECT round(COALESCE(sum(share_amount), 0), 2)
  INTO v_split_total
  FROM public.expense_splits
  WHERE expense_id = v_expense_id;

  IF v_total IS NOT NULL AND v_split_total <> round(v_total, 2) THEN
    RAISE EXCEPTION 'Expense split sum % does not equal total %', v_split_total, v_total;
  END IF;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER validate_expense_split_sum_trigger
AFTER INSERT OR UPDATE OR DELETE ON public.expense_splits
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validate_expense_split_sum();

CREATE FUNCTION public.validate_expense_total_split_sum()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_split_total numeric;
BEGIN
  SELECT round(COALESCE(sum(share_amount), 0), 2)
  INTO v_split_total
  FROM public.expense_splits
  WHERE expense_id = NEW.id;

  IF v_split_total <> round(NEW.total_amount, 2) THEN
    RAISE EXCEPTION 'Expense split sum % does not equal total %', v_split_total, NEW.total_amount;
  END IF;

  RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER validate_expense_total_split_sum_trigger
AFTER INSERT OR UPDATE OF total_amount ON public.expenses
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.validate_expense_total_split_sum();

CREATE FUNCTION public.validate_settlement_amount()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_share numeric;
  v_paid_by uuid;
  v_deleted_at timestamptz;
BEGIN
  SELECT s.share_amount, e.paid_by, e.deleted_at
  INTO v_share, v_paid_by, v_deleted_at
  FROM public.expense_splits s
  JOIN public.expenses e ON e.id = s.expense_id
  WHERE s.expense_id = NEW.expense_id
    AND s.user_id = NEW.payer_user_id;

  IF v_share IS NULL THEN
    RAISE EXCEPTION 'Settlement payer has no matching expense split';
  END IF;

  IF v_deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot settle a deleted expense';
  END IF;

  IF NEW.receiver_user_id <> v_paid_by THEN
    RAISE EXCEPTION 'Settlement receiver must be expense payer';
  END IF;

  IF NEW.amount <> v_share THEN
    RAISE EXCEPTION 'Settlement amount % does not equal split amount %', NEW.amount, v_share;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_settlement_amount_trigger
BEFORE INSERT OR UPDATE OF amount, expense_id, payer_user_id, receiver_user_id ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.validate_settlement_amount();

CREATE FUNCTION public.prevent_confirmed_settlement_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status = 'confirmed'
    AND (
      NEW.status <> OLD.status
      OR NEW.amount <> OLD.amount
      OR NEW.expense_id <> OLD.expense_id
      OR NEW.payer_user_id <> OLD.payer_user_id
      OR NEW.receiver_user_id <> OLD.receiver_user_id
      OR NEW.confirmed_at <> OLD.confirmed_at
    )
  THEN
    RAISE EXCEPTION 'Confirmed settlements are immutable';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_confirmed_settlement_mutation_trigger
BEFORE UPDATE ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.prevent_confirmed_settlement_mutation();

-- Authorization helper.
CREATE FUNCTION public.can_view_expense(p_expense_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.expenses e
    WHERE e.id = p_expense_id
      AND (
        e.created_by = auth.uid()
        OR e.paid_by = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.expense_splits s
          WHERE s.expense_id = e.id
            AND s.user_id = auth.uid()
        )
      )
  );
$$;

-- RLS.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT TO authenticated
WITH CHECK (auth.uid() = uid);

CREATE POLICY "Users can view relevant profiles"
ON public.users FOR SELECT TO authenticated
USING (
  auth.uid() = uid
  OR EXISTS (
    SELECT 1 FROM public.friendships f
    WHERE (f.user_id = auth.uid() AND f.friend_user_id = users.uid)
       OR (f.friend_user_id = auth.uid() AND f.user_id = users.uid)
  )
);

CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE TO authenticated
USING (auth.uid() = uid)
WITH CHECK (auth.uid() = uid);

CREATE POLICY "Users can view own friendships"
ON public.friendships FOR SELECT TO authenticated
USING (auth.uid() = user_id OR auth.uid() = friend_user_id);

CREATE POLICY "Users can view authorized expenses"
ON public.expenses FOR SELECT TO authenticated
USING (public.can_view_expense(id));

CREATE POLICY "Users can view authorized expense splits"
ON public.expense_splits FOR SELECT TO authenticated
USING (public.can_view_expense(expense_id));

CREATE POLICY "Users can view authorized settlements"
ON public.settlements FOR SELECT TO authenticated
USING (
  payer_user_id = auth.uid()
  OR receiver_user_id = auth.uid()
  OR public.can_view_expense(expense_id)
);

-- Ledger-derived views.
CREATE VIEW public.friend_balance_view
WITH (security_invoker = true)
AS
WITH active_debts AS (
  SELECT
    e.paid_by AS receiver_user_id,
    s.user_id AS payer_user_id,
    s.share_amount - COALESCE(sum(st.amount) FILTER (WHERE st.status = 'confirmed'), 0) AS amount
  FROM public.expenses e
  JOIN public.expense_splits s ON s.expense_id = e.id
  LEFT JOIN public.settlements st
    ON st.expense_id = e.id
   AND st.payer_user_id = s.user_id
   AND st.receiver_user_id = e.paid_by
   AND st.status = 'confirmed'
  WHERE e.deleted_at IS NULL
    AND s.user_id <> e.paid_by
  GROUP BY e.paid_by, s.user_id, s.share_amount
  HAVING s.share_amount - COALESCE(sum(st.amount) FILTER (WHERE st.status = 'confirmed'), 0) > 0
),
balance_rows AS (
  SELECT receiver_user_id AS user_id, payer_user_id AS friend_id, amount
  FROM active_debts
  UNION ALL
  SELECT payer_user_id AS user_id, receiver_user_id AS friend_id, -amount
  FROM active_debts
)
SELECT
  user_id,
  friend_id,
  round(sum(amount), 2) AS amount
FROM balance_rows
WHERE user_id = auth.uid()
GROUP BY user_id, friend_id
HAVING round(sum(amount), 2) <> 0;

CREATE VIEW public.user_balance_view
WITH (security_invoker = true)
AS
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
SELECT
  auth.uid() AS user_id,
  round(COALESCE(sum(amount) FILTER (WHERE amount > 0), 0), 2) AS total_owed,
  round(COALESCE(sum(abs(amount)) FILTER (WHERE amount < 0), 0), 2) AS total_owe,
  round(COALESCE(sum(amount), 0), 2) AS net_balance
FROM active_rows
WHERE user_id = auth.uid();

CREATE VIEW public.dashboard_totals_view
WITH (security_invoker = true)
AS
SELECT user_id, total_owed, total_owe, net_balance
FROM public.user_balance_view;

CREATE VIEW public.expense_ledger_history_view
WITH (security_invoker = true)
AS
SELECT
  e.id,
  e.expense_id,
  e.title,
  e.description,
  e.category,
  e.total_amount,
  e.paid_by,
  e.created_by,
  e.created_at,
  e.updated_at,
  e.deleted_at,
  e.deleted_by,
  e.split_type,
  e.notes,
  COALESCE(
    jsonb_object_agg(
      s.user_id::text,
      jsonb_build_object(
        'amount', s.share_amount,
        'settled', confirmed.id IS NOT NULL,
        'settledAt', confirmed.confirmed_at,
        'settlementRequestedAt', requested.created_at
      )
    ) FILTER (WHERE s.user_id IS NOT NULL),
    '{}'::jsonb
  ) AS splits
FROM public.expenses e
LEFT JOIN public.expense_splits s ON s.expense_id = e.id
LEFT JOIN public.settlements confirmed
  ON confirmed.expense_id = e.id
 AND confirmed.payer_user_id = s.user_id
 AND confirmed.receiver_user_id = e.paid_by
 AND confirmed.status = 'confirmed'
LEFT JOIN public.settlements requested
  ON requested.expense_id = e.id
 AND requested.payer_user_id = s.user_id
 AND requested.receiver_user_id = e.paid_by
 AND requested.status = 'requested'
WHERE public.can_view_expense(e.id)
GROUP BY e.id;

-- RPCs.
CREATE FUNCTION public.create_expense_with_balances(p_expense jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_expense_id uuid;
  v_total numeric := round((p_expense->>'total_amount')::numeric, 2);
  v_paid_by uuid := (p_expense->>'paid_by')::uuid;
  v_created_by uuid := (p_expense->>'created_by')::uuid;
  v_splits jsonb := p_expense->'splits';
  v_split_total numeric;
  v_has_negative boolean;
  v_entry record;
  v_share numeric;
  v_expense public.expenses;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF (p_expense->>'expense_id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'expense_id must be UUIDv4';
  END IF;
  v_expense_id := (p_expense->>'expense_id')::uuid;

  IF v_created_by <> v_auth OR v_paid_by <> v_auth THEN
    RAISE EXCEPTION 'Only authenticated payer can create expense';
  END IF;

  IF v_total <= 0 THEN
    RAISE EXCEPTION 'Total amount must be positive';
  END IF;

  IF jsonb_typeof(v_splits) <> 'object' THEN
    RAISE EXCEPTION 'Splits must be an object';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM jsonb_each(v_splits) WHERE key::uuid = v_paid_by) THEN
    RAISE EXCEPTION 'Payer must be included in splits';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_each(v_splits) split
    LEFT JOIN public.users participant ON participant.uid = split.key::uuid
    WHERE participant.uid IS NULL
      OR (
        split.key::uuid <> v_paid_by
        AND NOT EXISTS (
          SELECT 1 FROM public.friendships f
          WHERE (f.user_id = v_paid_by AND f.friend_user_id = split.key::uuid)
             OR (f.friend_user_id = v_paid_by AND f.user_id = split.key::uuid)
        )
      )
  ) THEN
    RAISE EXCEPTION 'All split participants must be existing friends of payer';
  END IF;

  SELECT
    round(COALESCE(sum(round((value->>'amount')::numeric, 2)), 0), 2),
    COALESCE(bool_or((value->>'amount')::numeric < 0), false)
  INTO v_split_total, v_has_negative
  FROM jsonb_each(v_splits);

  IF v_has_negative THEN
    RAISE EXCEPTION 'Split amounts cannot be negative';
  END IF;

  IF v_split_total <> v_total THEN
    RAISE EXCEPTION 'Split amounts must equal total';
  END IF;

  INSERT INTO public.expenses (
    expense_id,
    title,
    description,
    category,
    total_amount,
    paid_by,
    created_by,
    split_type,
    notes,
    created_at
  )
  VALUES (
    v_expense_id,
    p_expense->>'title',
    NULLIF(p_expense->>'description', ''),
    p_expense->>'category',
    v_total,
    v_paid_by,
    v_created_by,
    COALESCE(NULLIF(p_expense->>'split_type', ''), 'custom'),
    NULLIF(p_expense->>'notes', ''),
    COALESCE(NULLIF(p_expense->>'created_at', '')::timestamptz, now())
  )
  RETURNING * INTO v_expense;

  FOR v_entry IN SELECT key, value FROM jsonb_each(v_splits)
  LOOP
    v_share := round((v_entry.value->>'amount')::numeric, 2);
    INSERT INTO public.expense_splits (expense_id, user_id, share_amount, created_at)
    VALUES (v_expense.id, v_entry.key::uuid, v_share, v_expense.created_at);
  END LOOP;

  RETURN (
    SELECT to_jsonb(h)
    FROM public.expense_ledger_history_view h
    WHERE h.id = v_expense.id
  );
END;
$$;

CREATE FUNCTION public.request_settlement(p_expense_id text, split_updates jsonb DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_expense public.expenses;
  v_split public.expense_splits;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_expense_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'Invalid expense id';
  END IF;

  SELECT * INTO v_expense
  FROM public.expenses
  WHERE id = p_expense_id::uuid
  FOR UPDATE;

  IF NOT FOUND OR v_expense.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF v_auth = v_expense.paid_by THEN
    RAISE EXCEPTION 'Payer cannot request settlement';
  END IF;

  SELECT * INTO v_split
  FROM public.expense_splits
  WHERE expense_id = v_expense.id
    AND user_id = v_auth
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Not a participant';
  END IF;

  IF v_split.share_amount <= 0 THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.settlements
    WHERE expense_id = v_expense.id
      AND payer_user_id = v_auth
      AND receiver_user_id = v_expense.paid_by
      AND status IN ('requested', 'confirmed')
  ) THEN
    RETURN;
  END IF;

  INSERT INTO public.settlements (expense_id, payer_user_id, receiver_user_id, amount, status)
  VALUES (v_expense.id, v_auth, v_expense.paid_by, v_split.share_amount, 'requested');
END;
$$;

CREATE FUNCTION public.confirm_settlement(p_expense_id text, p_participant_uid text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_participant uuid := p_participant_uid::uuid;
  v_expense public.expenses;
  v_split public.expense_splits;
  v_settlement public.settlements;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_expense_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'Invalid expense id';
  END IF;

  SELECT * INTO v_expense
  FROM public.expenses
  WHERE id = p_expense_id::uuid
  FOR UPDATE;

  IF NOT FOUND OR v_expense.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF v_auth <> v_expense.paid_by THEN
    RAISE EXCEPTION 'Only payer can confirm settlement';
  END IF;

  IF v_participant = v_expense.paid_by THEN
    RAISE EXCEPTION 'Payer split cannot be settled';
  END IF;

  SELECT * INTO v_split
  FROM public.expense_splits
  WHERE expense_id = v_expense.id
    AND user_id = v_participant
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participant split not found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.settlements
    WHERE expense_id = v_expense.id
      AND payer_user_id = v_participant
      AND receiver_user_id = v_expense.paid_by
      AND status = 'confirmed'
  ) THEN
    RETURN;
  END IF;

  SELECT * INTO v_settlement
  FROM public.settlements
  WHERE expense_id = v_expense.id
    AND payer_user_id = v_participant
    AND receiver_user_id = v_expense.paid_by
    AND status = 'requested'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Settlement has not been requested';
  END IF;

  IF v_settlement.amount <> v_split.share_amount THEN
    RAISE EXCEPTION 'Settlement amount does not match outstanding debt';
  END IF;

  UPDATE public.settlements
  SET status = 'confirmed',
      confirmed_at = now()
  WHERE id = v_settlement.id;
END;
$$;

CREATE FUNCTION public.reject_settlement(p_expense_id text, p_participant_uid text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_participant uuid := p_participant_uid::uuid;
  v_expense public.expenses;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_expense_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'Invalid expense id';
  END IF;

  SELECT * INTO v_expense
  FROM public.expenses
  WHERE id = p_expense_id::uuid
  FOR UPDATE;

  IF NOT FOUND OR v_expense.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF v_auth <> v_expense.paid_by THEN
    RAISE EXCEPTION 'Only payer can reject settlement';
  END IF;

  UPDATE public.settlements
  SET status = 'rejected'
  WHERE expense_id = v_expense.id
    AND payer_user_id = v_participant
    AND receiver_user_id = v_expense.paid_by
    AND status = 'requested';
END;
$$;

CREATE FUNCTION public.delete_expense_with_balances(p_expense_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_expense public.expenses;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_expense_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION 'Invalid expense id';
  END IF;

  SELECT * INTO v_expense
  FROM public.expenses
  WHERE id = p_expense_id::uuid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Expense not found';
  END IF;

  IF v_auth <> v_expense.created_by THEN
    RAISE EXCEPTION 'Only creator can delete';
  END IF;

  IF v_expense.deleted_at IS NOT NULL THEN
    RETURN;
  END IF;

  UPDATE public.settlements
  SET status = 'rejected'
  WHERE expense_id = v_expense.id
    AND status = 'requested';

  UPDATE public.expenses
  SET deleted_at = now(),
      deleted_by = v_auth
  WHERE id = v_expense.id;
END;
$$;

CREATE FUNCTION public.add_friend_secure(target_uid text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_target uuid := target_uid::uuid;
  v_user_a uuid;
  v_user_b uuid;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_target = v_auth THEN
    RAISE EXCEPTION 'Cannot add yourself as a friend';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.users WHERE uid = v_target) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  v_user_a := LEAST(v_auth, v_target);
  v_user_b := GREATEST(v_auth, v_target);

  INSERT INTO public.friendships (user_id, friend_user_id)
  VALUES (v_user_a, v_user_b)
  ON CONFLICT DO NOTHING;
END;
$$;

CREATE FUNCTION public.remove_friend_secure(target_uid text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_target uuid := target_uid::uuid;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF v_target = v_auth THEN
    RAISE EXCEPTION 'Invalid friend';
  END IF;

  PERFORM 1 FROM public.users WHERE uid IN (v_auth, v_target) FOR UPDATE;

  IF NOT EXISTS (
    SELECT 1 FROM public.friendships
    WHERE (user_id = v_auth AND friend_user_id = v_target)
       OR (user_id = v_target AND friend_user_id = v_auth)
  ) THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.expenses e
    JOIN public.expense_splits s ON s.expense_id = e.id
    WHERE e.deleted_at IS NULL
      AND s.user_id <> e.paid_by
      AND s.share_amount > 0
      AND (
        (e.paid_by = v_auth AND s.user_id = v_target)
        OR (e.paid_by = v_target AND s.user_id = v_auth)
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.settlements st
        WHERE st.expense_id = e.id
          AND st.payer_user_id = s.user_id
          AND st.receiver_user_id = e.paid_by
          AND st.status = 'confirmed'
      )
  ) THEN
    RAISE EXCEPTION 'Settle all balances before removing friend';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.settlements st
    JOIN public.expenses e ON e.id = st.expense_id
    WHERE e.deleted_at IS NULL
      AND st.status = 'requested'
      AND (
        (st.payer_user_id = v_auth AND st.receiver_user_id = v_target)
        OR (st.payer_user_id = v_target AND st.receiver_user_id = v_auth)
      )
  ) THEN
    RAISE EXCEPTION 'Resolve pending settlement requests before removing friend';
  END IF;

  DELETE FROM public.friendships
  WHERE (user_id = v_auth AND friend_user_id = v_target)
     OR (user_id = v_target AND friend_user_id = v_auth);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.create_expense_with_balances(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.request_settlement(text, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.confirm_settlement(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reject_settlement(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.delete_expense_with_balances(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_friend_secure(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.remove_friend_secure(text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_expense_with_balances(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_settlement(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_settlement(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_settlement(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_expense_with_balances(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_friend_secure(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friend_secure(text) TO authenticated;

GRANT SELECT ON public.friend_balance_view TO authenticated;
GRANT SELECT ON public.user_balance_view TO authenticated;
GRANT SELECT ON public.dashboard_totals_view TO authenticated;
GRANT SELECT ON public.expense_ledger_history_view TO authenticated;

COMMIT;
