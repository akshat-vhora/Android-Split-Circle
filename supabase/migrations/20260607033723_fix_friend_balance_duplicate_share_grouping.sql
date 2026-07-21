BEGIN;

DROP VIEW IF EXISTS public.dashboard_totals_view CASCADE;
DROP VIEW IF EXISTS public.user_balance_view CASCADE;
DROP VIEW IF EXISTS public.friend_balance_view CASCADE;

CREATE VIEW public.friend_balance_view
WITH (security_invoker = true)
AS
WITH split_debts AS (
  SELECT
    e.id AS expense_id,
    e.paid_by AS receiver_user_id,
    s.user_id AS payer_user_id,
    s.share_amount
      - COALESCE(sum(st.amount) FILTER (WHERE st.status = 'confirmed'), 0) AS amount
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
  HAVING s.share_amount
    - COALESCE(sum(st.amount) FILTER (WHERE st.status = 'confirmed'), 0) > 0
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

GRANT SELECT ON public.friend_balance_view TO authenticated;
GRANT SELECT ON public.user_balance_view TO authenticated;
GRANT SELECT ON public.dashboard_totals_view TO authenticated;

COMMIT;
