BEGIN;

DROP VIEW IF EXISTS public.dashboard_totals_view CASCADE;
DROP VIEW IF EXISTS public.user_balance_view CASCADE;

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

GRANT SELECT ON public.user_balance_view TO authenticated;
GRANT SELECT ON public.dashboard_totals_view TO authenticated;

COMMIT;
