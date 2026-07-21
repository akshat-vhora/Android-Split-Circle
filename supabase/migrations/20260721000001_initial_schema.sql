BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE public.users (
  uid uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL CHECK (btrim(display_name) <> ''),
  email text NOT NULL UNIQUE CHECK (position('@' in email) > 1),
  unique_id text NOT NULL UNIQUE CHECK (btrim(unique_id) <> ''),
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
  deleted_at timestamptz
);

CREATE TABLE public.expense_splits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE RESTRICT,
  share_amount numeric(12,2) NOT NULL CHECK (share_amount >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (expense_id, user_id)
);

CREATE TABLE public.settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id uuid NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
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

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('friend_added', 'expense_added', 'settlement_requested', 'settlement_confirmed', 'settlement_rejected', 'reminder')),
  title text NOT NULL,
  body text,
  data jsonb DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.rate_limits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action text NOT NULL,
  window_start timestamptz NOT NULL DEFAULT now(),
  count integer NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX friendships_reverse_pair_key
  ON public.friendships (LEAST(user_id, friend_user_id), GREATEST(user_id, friend_user_id));

CREATE INDEX idx_friendships_user ON public.friendships(user_id);
CREATE INDEX idx_friendships_friend ON public.friendships(friend_user_id);
CREATE INDEX idx_expenses_paid_by ON public.expenses(paid_by);
CREATE INDEX idx_expenses_created_by ON public.expenses(created_by);
CREATE INDEX idx_expenses_created_at ON public.expenses (created_at DESC);
CREATE INDEX idx_expenses_deleted_at ON public.expenses (deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_expenses_paid_created ON public.expenses (paid_by, created_at DESC);
CREATE INDEX idx_expense_splits_expense ON public.expense_splits(expense_id);
CREATE INDEX idx_expense_splits_user ON public.expense_splits(user_id);
CREATE INDEX idx_expense_splits_user_expense ON public.expense_splits (user_id, expense_id);
CREATE INDEX idx_settlements_payer ON public.settlements(payer_user_id);
CREATE INDEX idx_settlements_receiver ON public.settlements(receiver_user_id);
CREATE INDEX idx_settlements_expense_payer_status ON public.settlements (expense_id, payer_user_id, status);
CREATE INDEX idx_settlements_expense_status ON public.settlements (expense_id, status);
CREATE INDEX idx_notifications_user_id ON public.notifications (user_id);
CREATE INDEX idx_notifications_unread ON public.notifications (user_id) WHERE NOT is_read;
CREATE INDEX idx_notifications_created_at ON public.notifications (user_id, created_at DESC);
CREATE INDEX idx_rate_limits_lookup ON public.rate_limits (user_id, action, window_start DESC);

CREATE UNIQUE INDEX settlements_one_requested
  ON public.settlements(expense_id, payer_user_id, receiver_user_id)
  WHERE status = 'requested';

CREATE UNIQUE INDEX settlements_one_confirmed
  ON public.settlements(expense_id, payer_user_id, receiver_user_id)
  WHERE status = 'confirmed';

CREATE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

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
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'confirmed' THEN
    RAISE EXCEPTION 'Confirmed settlements are immutable and cannot be modified or deleted';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_confirmed_settlement_mutation_trigger
BEFORE DELETE OR UPDATE ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.prevent_confirmed_settlement_mutation();

CREATE FUNCTION public.prevent_settled_split_modification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.settlements
    WHERE expense_id = OLD.expense_id
      AND payer_user_id = OLD.user_id
      AND status = 'confirmed'
  ) THEN
    RAISE EXCEPTION 'Cannot modify a split that has already been confirmed settled';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_settled_split_modification_trigger
BEFORE UPDATE ON public.expense_splits
FOR EACH ROW
EXECUTE FUNCTION public.prevent_settled_split_modification();

CREATE FUNCTION public.can_view_expense(p_expense_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_auth uuid := auth.uid();
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.expenses e
    WHERE e.id = p_expense_id
      AND (
        e.created_by = v_auth
        OR e.paid_by = v_auth
        OR EXISTS (
          SELECT 1
          FROM public.expense_splits s
          WHERE s.expense_id = e.id
            AND s.user_id = v_auth
        )
      )
  );
END;
$$;

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT TO authenticated
WITH CHECK (auth.uid() = uid);

CREATE POLICY "Users can view own profile"
ON public.users FOR SELECT TO authenticated
USING (auth.uid() = uid);

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

CREATE POLICY "Users can view own notifications"
ON public.notifications FOR SELECT TO public
USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications"
ON public.notifications FOR UPDATE TO public
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
ON public.notifications FOR DELETE TO public
USING (auth.uid() = user_id);

CREATE POLICY "Block direct insert on expenses"
  ON public.expenses FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct update on expenses"
  ON public.expenses FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY "Block direct delete on expenses"
  ON public.expenses FOR DELETE TO authenticated USING (false);

CREATE POLICY "Block direct insert on expense_splits"
  ON public.expense_splits FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct update on expense_splits"
  ON public.expense_splits FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY "Block direct delete on expense_splits"
  ON public.expense_splits FOR DELETE TO authenticated USING (false);

CREATE POLICY "Block direct insert on settlements"
  ON public.settlements FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct update on settlements"
  ON public.settlements FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY "Block direct delete on settlements"
  ON public.settlements FOR DELETE TO authenticated USING (false);

CREATE POLICY "Block direct insert on friendships"
  ON public.friendships FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct delete on friendships"
  ON public.friendships FOR DELETE TO authenticated USING (false);

CREATE VIEW public.friend_balance_view
WITH (security_invoker = true)
AS
WITH split_debts AS (
  SELECT
    e.id AS expense_id,
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
  GROUP BY e.id, e.paid_by, s.user_id, s.share_amount
  HAVING s.share_amount - COALESCE(sum(st.amount) FILTER (WHERE st.status = 'confirmed'), 0) > 0
),
balance_rows AS (
  SELECT receiver_user_id AS user_id, payer_user_id AS friend_id, amount
  FROM split_debts
  UNION ALL
  SELECT payer_user_id AS user_id, receiver_user_id AS friend_id, -amount
  FROM split_debts
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
SELECT
  auth.uid() AS user_id,
  round(COALESCE(sum(amount) FILTER (WHERE amount > 0), 0), 2) AS total_owed,
  round(COALESCE(sum(abs(amount)) FILTER (WHERE amount < 0), 0), 2) AS total_owe,
  round(COALESCE(sum(amount), 0), 2) AS net_balance
FROM public.friend_balance_view
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
  e.deleted_at,
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
WHERE e.deleted_at IS NULL
  AND public.can_view_expense(e.id)
GROUP BY e.id;

CREATE VIEW public.expense_audit_log_view
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
  ) AS splits,
  e.deleted_at,
  CASE WHEN e.deleted_at IS NOT NULL THEN true ELSE false END AS is_deleted
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

CREATE FUNCTION public.check_rate_limit(
  p_action text,
  p_max_requests integer,
  p_window_seconds integer DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_count int;
  v_window timestamptz;
BEGIN
  IF v_auth IS NULL THEN
    RETURN false;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(v_auth::text || '_' || p_action));

  v_window := now() - (p_window_seconds || ' seconds')::interval;

  DELETE FROM public.rate_limits
  WHERE user_id = v_auth
    AND action = p_action
    AND window_start < v_window;

  SELECT COUNT(*) INTO v_count
  FROM public.rate_limits
  WHERE user_id = v_auth
    AND action = p_action
    AND window_start >= v_window;

  IF v_count >= p_max_requests THEN
    RETURN false;
  END IF;

  INSERT INTO public.rate_limits (user_id, action)
  VALUES (v_auth, p_action);

  RETURN true;
END;
$$;

CREATE FUNCTION public.create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text DEFAULT NULL,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data);
END;
$$;

CREATE FUNCTION public.on_friendship_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_a_name text;
  v_user_b_name text;
  v_user_a_id uuid := LEAST(NEW.user_id, NEW.friend_user_id);
  v_user_b_id uuid := GREATEST(NEW.user_id, NEW.friend_user_id);
BEGIN
  SELECT display_name INTO v_user_a_name FROM public.users WHERE uid = v_user_a_id;
  SELECT display_name INTO v_user_b_name FROM public.users WHERE uid = v_user_b_id;

  PERFORM public.create_notification(
    p_user_id => v_user_a_id,
    p_type => 'friend_added',
    p_title => 'New friend!',
    p_body => v_user_b_name || ' added you as a friend',
    p_data => jsonb_build_object('friend_uid', v_user_b_id, 'friend_name', v_user_b_name)
  );

  PERFORM public.create_notification(
    p_user_id => v_user_b_id,
    p_type => 'friend_added',
    p_title => 'New friend!',
    p_body => v_user_a_name || ' added you as a friend',
    p_data => jsonb_build_object('friend_uid', v_user_a_id, 'friend_name', v_user_a_name)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_friendship_notify
AFTER INSERT ON public.friendships
FOR EACH ROW
EXECUTE FUNCTION public.on_friendship_insert();

CREATE FUNCTION public.on_settlement_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payer_name text;
  v_expense_title text;
  v_amount_text text;
BEGIN
  IF NEW.status <> 'requested' THEN
    RETURN NEW;
  END IF;

  SELECT display_name INTO v_payer_name FROM public.users WHERE uid = NEW.payer_user_id;
  SELECT title INTO v_expense_title FROM public.expenses WHERE id = NEW.expense_id;
  v_amount_text := '₹' || round(NEW.amount, 2)::text;

  PERFORM public.create_notification(
    p_user_id => NEW.receiver_user_id,
    p_type => 'settlement_requested',
    p_title => 'Settlement requested',
    p_body => v_payer_name || ' wants to settle ' || v_amount_text || ' for "' || v_expense_title || '"',
    p_data => jsonb_build_object('expense_id', NEW.expense_id, 'expense_title', v_expense_title, 'actor_uid', NEW.payer_user_id, 'actor_name', v_payer_name, 'amount', NEW.amount)
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_settlement_insert_notify
AFTER INSERT ON public.settlements
FOR EACH ROW
EXECUTE FUNCTION public.on_settlement_insert();

CREATE FUNCTION public.on_settlement_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_receiver_name text;
  v_expense_title text;
  v_amount_text text;
BEGIN
  IF OLD.status <> 'requested' THEN
    RETURN NEW;
  END IF;

  SELECT display_name INTO v_receiver_name FROM public.users WHERE uid = NEW.receiver_user_id;
  SELECT title INTO v_expense_title FROM public.expenses WHERE id = NEW.expense_id;
  v_amount_text := '₹' || round(NEW.amount, 2)::text;

  IF NEW.status = 'confirmed' THEN
    PERFORM public.create_notification(
      p_user_id => NEW.payer_user_id,
      p_type => 'settlement_confirmed',
      p_title => 'Settlement confirmed',
      p_body => v_receiver_name || ' confirmed your settlement of ' || v_amount_text || ' for "' || v_expense_title || '"',
      p_data => jsonb_build_object('expense_id', NEW.expense_id, 'expense_title', v_expense_title, 'actor_uid', NEW.receiver_user_id, 'actor_name', v_receiver_name, 'amount', NEW.amount)
    );
  ELSIF NEW.status = 'rejected' THEN
    PERFORM public.create_notification(
      p_user_id => NEW.payer_user_id,
      p_type => 'settlement_rejected',
      p_title => 'Settlement rejected',
      p_body => v_receiver_name || ' rejected your settlement of ' || v_amount_text || ' for "' || v_expense_title || '"',
      p_data => jsonb_build_object('expense_id', NEW.expense_id, 'expense_title', v_expense_title, 'actor_uid', NEW.receiver_user_id, 'actor_name', v_receiver_name, 'amount', NEW.amount)
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_settlement_update_notify
AFTER UPDATE ON public.settlements
FOR EACH ROW
WHEN (OLD.status = 'requested' AND NEW.status IN ('confirmed', 'rejected'))
EXECUTE FUNCTION public.on_settlement_update();

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
  v_participant_name text;
  v_participant_uuids uuid[];
  v_other_uid uuid;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF NOT check_rate_limit('create_expense', 10, 60) THEN
    RAISE EXCEPTION 'Too many expenses created. Please slow down.';
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

  SELECT array_agg(key::uuid)
  INTO v_participant_uuids
  FROM jsonb_each(v_splits)
  WHERE key::uuid <> v_paid_by;

  IF v_participant_uuids IS NOT NULL THEN
    PERFORM 1
    FROM public.friendships f
    WHERE (f.user_id = v_paid_by AND f.friend_user_id = ANY(v_participant_uuids))
       OR (f.friend_user_id = v_paid_by AND f.user_id = ANY(v_participant_uuids))
    FOR UPDATE;
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
    expense_id, title, description, category, total_amount,
    paid_by, created_by, split_type, notes, created_at
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

  SELECT display_name INTO v_participant_name FROM public.users WHERE uid = v_auth;
  FOR v_entry IN SELECT key FROM jsonb_each(v_splits)
  LOOP
    IF v_entry.key::uuid <> v_auth THEN
      PERFORM public.create_notification(
        p_user_id => v_entry.key::uuid,
        p_type => 'expense_added',
        p_title => 'New expense added',
        p_body => v_participant_name || ' added "' || v_expense.title || '" — your share: $' || round(((v_splits->>v_entry.key)::jsonb->>'amount')::numeric, 2)::text,
        p_data => jsonb_build_object('expense_id', v_expense.id, 'expense_title', v_expense.title, 'actor_uid', v_auth, 'actor_name', v_participant_name, 'total_amount', v_total)
      );
    END IF;
  END LOOP;

  RETURN (
    SELECT to_jsonb(h)
    FROM public.expense_ledger_history_view h
    WHERE h.id = v_expense.id
  );
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

  UPDATE public.expenses SET deleted_at = now() WHERE id = v_expense.id;
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

  IF NOT check_rate_limit('request_settlement', 20, 60) THEN
    RAISE EXCEPTION 'Too many settlement requests. Please slow down.';
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

  IF NOT check_rate_limit('confirm_settlement', 30, 60) THEN
    RAISE EXCEPTION 'Too many confirmations. Please slow down.';
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

  IF v_expense.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Cannot confirm settlement on a deleted expense';
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
  SET status = 'confirmed', confirmed_at = now()
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

  IF NOT check_rate_limit('reject_settlement', 30, 60) THEN
    RAISE EXCEPTION 'Too many rejections. Please slow down.';
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

  IF v_auth <> v_expense.paid_by THEN
    RAISE EXCEPTION 'Only payer can reject settlement';
  END IF;

  UPDATE public.settlements
  SET status = 'rejected'
  WHERE expense_id = v_expense.id
    AND payer_user_id = v_participant
    AND receiver_user_id = v_expense.paid_by
    AND status = 'requested';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No requested settlement found to reject for this expense and participant';
  END IF;
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

  PERFORM 1 FROM public.friendships
  WHERE (user_id = LEAST(v_auth, v_target) AND friend_user_id = GREATEST(v_auth, v_target))
  FOR UPDATE;

  IF NOT FOUND THEN
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

CREATE FUNCTION public.find_user_by_unique_id(p_unique_id text)
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
    'unique_id', v_user.unique_id
  );
END;
$$;

CREATE FUNCTION public.get_expenses_page(
  p_auth text,
  p_page integer DEFAULT 0,
  p_page_size integer DEFAULT 20,
  p_tab integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_offset int := p_page * p_page_size;
  v_result jsonb;
BEGIN
  IF p_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  WITH page AS (
    SELECT e.id
    FROM public.expenses e
    WHERE can_view_expense(e.id)
      AND e.deleted_at IS NULL
      AND (
        p_tab = 0
        OR (p_tab = 2 AND e.paid_by = p_auth::uuid)
        OR (p_tab = 1 AND e.paid_by <> p_auth::uuid)
      )
    ORDER BY e.created_at DESC
    LIMIT p_page_size
    OFFSET v_offset
  )
  SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM page p
  JOIN public.expense_ledger_history_view h ON h.id = p.id;

  RETURN v_result;
END;
$$;

CREATE FUNCTION public.get_awaiting_confirmation(p_auth uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF p_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM public.expense_ledger_history_view h
  WHERE h.paid_by = p_auth
    AND EXISTS (
      SELECT 1
      FROM jsonb_each(h.splits) s
      WHERE (s.value->>'settlementRequestedAt') IS NOT NULL
        AND NOT COALESCE((s.value->>'settled')::boolean, false)
    );

  RETURN v_result;
END;
$$;

CREATE FUNCTION public.get_user_notifications(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_result jsonb;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', n.id,
      'user_id', n.user_id,
      'type', n.type,
      'title', n.title,
      'body', n.body,
      'data', n.data,
      'is_read', n.is_read,
      'created_at', n.created_at
    ) ORDER BY n.created_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM public.notifications n
  WHERE n.user_id = v_auth
  LIMIT p_limit
  OFFSET p_offset;

  RETURN v_result;
END;
$$;

CREATE FUNCTION public.get_unread_notification_count()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_count integer;
BEGIN
  IF v_auth IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*) INTO v_count
  FROM public.notifications
  WHERE user_id = v_auth AND NOT is_read;

  RETURN v_count;
END;
$$;

CREATE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.notifications
  SET is_read = true
  WHERE id = p_notification_id AND user_id = v_auth;
END;
$$;

CREATE FUNCTION public.mark_all_notifications_read()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  UPDATE public.notifications
  SET is_read = true
  WHERE user_id = v_auth AND NOT is_read;
END;
$$;

CREATE FUNCTION public.delete_notification(p_notification_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  DELETE FROM public.notifications
  WHERE id = p_notification_id AND user_id = v_auth;
END;
$$;

CREATE FUNCTION public.clear_all_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  DELETE FROM public.notifications
  WHERE user_id = v_auth;
END;
$$;

CREATE FUNCTION public.send_reminder(p_expense_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth uuid := auth.uid();
  v_expense_title text;
  v_payer_name text;
  v_payer_uid uuid;
  v_recipient record;
BEGIN
  IF v_auth IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  SELECT e.title, e.paid_by INTO v_expense_title, v_payer_uid
  FROM public.expenses e
  WHERE e.id = p_expense_id;

  IF v_payer_uid <> v_auth THEN
    RAISE EXCEPTION 'Only the payer can send reminders';
  END IF;

  SELECT display_name INTO v_payer_name
  FROM public.users
  WHERE uid = v_auth;

  FOR v_recipient IN
    SELECT s.user_id
    FROM public.expense_splits s
    WHERE s.expense_id = p_expense_id
      AND s.user_id <> v_payer_uid
      AND NOT EXISTS (
        SELECT 1 FROM public.settlements st
        WHERE st.expense_id = p_expense_id
          AND st.payer_user_id = s.user_id
          AND st.receiver_user_id = v_payer_uid
          AND st.status = 'confirmed'
      )
  LOOP
    PERFORM public.create_notification(
      p_user_id => v_recipient.user_id,
      p_type => 'reminder',
      p_title => 'Payment reminder',
      p_body => v_payer_name || ' reminded you to settle "' || v_expense_title || '"',
      p_data => jsonb_build_object(
        'actor_uid', v_auth,
        'actor_name', v_payer_name,
        'expense_id', p_expense_id,
        'expense_title', v_expense_title
      )
    );
  END LOOP;
END;
$$;

CREATE FUNCTION public.get_reminder_cooldown(p_expense_id uuid, p_target_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_last_at timestamptz;
  v_cooldown_seconds int := 300;
BEGIN
  SELECT created_at INTO v_last_at
  FROM public.notifications
  WHERE user_id = p_target_user_id
    AND type = 'reminder'
    AND data->>'expense_id' = p_expense_id::text
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_at IS NULL THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(0, v_cooldown_seconds - EXTRACT(EPOCH FROM (now() - v_last_at))::int);
END;
$$;

CREATE FUNCTION public.check_ledger_invariants()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  violations jsonb := '[]'::jsonb;
  v_count int;
  v_row record;
BEGIN
  FOR v_row IN
    SELECT e.id, e.total_amount, round(COALESCE(sum(s.share_amount), 0), 2) AS split_sum
    FROM expenses e
    LEFT JOIN expense_splits s ON s.expense_id = e.id
    GROUP BY e.id, e.total_amount
    HAVING round(COALESCE(sum(s.share_amount), 0), 2) <> round(e.total_amount, 2)
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I1: split_sum = total_amount',
      'expense_id', v_row.id,
      'total_amount', v_row.total_amount,
      'split_sum', v_row.split_sum
    );
  END LOOP;

  FOR v_row IN
    SELECT st.id AS settlement_id, st.expense_id
    FROM settlements st
    LEFT JOIN expenses e ON e.id = st.expense_id
    WHERE e.id IS NULL
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I2: no orphan settlements',
      'settlement_id', v_row.settlement_id,
      'expense_id', v_row.expense_id
    );
  END LOOP;

  FOR v_row IN
    SELECT s.id AS split_id, s.expense_id
    FROM expense_splits s
    LEFT JOIN expenses e ON e.id = s.expense_id
    WHERE e.id IS NULL
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I3: no orphan splits',
      'split_id', v_row.split_id,
      'expense_id', v_row.expense_id
    );
  END LOOP;

  FOR v_row IN
    SELECT expense_id, payer_user_id, receiver_user_id, COUNT(*) AS cnt
    FROM settlements
    WHERE status = 'confirmed'
    GROUP BY expense_id, payer_user_id, receiver_user_id
    HAVING COUNT(*) > 1
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I4: no duplicate confirmed settlements',
      'expense_id', v_row.expense_id,
      'payer_user_id', v_row.payer_user_id,
      'receiver_user_id', v_row.receiver_user_id,
      'count', v_row.cnt
    );
  END LOOP;

  FOR v_row IN
    SELECT expense_id, payer_user_id, receiver_user_id, COUNT(*) AS cnt
    FROM settlements
    WHERE status = 'requested'
    GROUP BY expense_id, payer_user_id, receiver_user_id
    HAVING COUNT(*) > 1
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I5: no duplicate requested settlements',
      'expense_id', v_row.expense_id,
      'payer_user_id', v_row.payer_user_id,
      'receiver_user_id', v_row.receiver_user_id,
      'count', v_row.cnt
    );
  END LOOP;

  FOR v_row IN
    SELECT st.id, st.amount, s.share_amount, st.expense_id, st.payer_user_id
    FROM settlements st
    JOIN expense_splits s ON s.expense_id = st.expense_id AND s.user_id = st.payer_user_id
    WHERE round(st.amount, 2) <> round(s.share_amount, 2)
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I6: settlement amount = split amount',
      'settlement_id', v_row.id,
      'settlement_amount', v_row.amount,
      'split_amount', v_row.share_amount
    );
  END LOOP;

  FOR v_row IN
    SELECT st.id, st.receiver_user_id, e.paid_by
    FROM settlements st
    JOIN expenses e ON e.id = st.expense_id
    WHERE st.receiver_user_id <> e.paid_by
  LOOP
    violations := violations || jsonb_build_object(
      'invariant', 'I8: settlement receiver = expense payer',
      'settlement_id', v_row.id,
      'receiver', v_row.receiver_user_id,
      'expected_payer', v_row.paid_by
    );
  END LOOP;

  RETURN violations;
END;
$$;

CREATE FUNCTION public.count_invariant_violations()
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE((SELECT COUNT(*) FROM jsonb_array_elements(check_ledger_invariants())), 0);
$$;

REVOKE EXECUTE ON FUNCTION public.can_view_expense(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_expense_split_sum() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_expense_total_split_sum() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_settlement_amount() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_expense_with_balances(jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.request_settlement(text, jsonb) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.confirm_settlement(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.reject_settlement(text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.delete_expense_with_balances(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_friend_secure(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.remove_friend_secure(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.find_user_by_unique_id(text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.create_notification(uuid, text, text, text, jsonb) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_expense_with_balances(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_settlement(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_settlement(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_settlement(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_expense_with_balances(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_friend_secure(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friend_secure(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_user_by_unique_id(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_notifications(integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_notification(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_all_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_expenses_page(text, integer, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_awaiting_confirmation(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_reminder(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reminder_cooldown(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_notification(uuid, text, text, text, jsonb) TO authenticated;

GRANT SELECT ON public.friend_balance_view TO authenticated;
GRANT SELECT ON public.user_balance_view TO authenticated;
GRANT SELECT ON public.dashboard_totals_view TO authenticated;
GRANT SELECT ON public.expense_ledger_history_view TO authenticated;
GRANT SELECT ON public.expense_audit_log_view TO authenticated;

GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT ON public.expenses TO authenticated;
GRANT SELECT ON public.expense_splits TO authenticated;
GRANT SELECT ON public.settlements TO authenticated;
GRANT SELECT ON public.friendships TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;

COMMIT;
