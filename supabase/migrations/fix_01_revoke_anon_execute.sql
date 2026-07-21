-- Revoke anon/public execute on all validation and helper functions
REVOKE EXECUTE ON FUNCTION public.can_view_expense(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_expense_split_sum() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_expense_total_split_sum() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.validate_settlement_amount() FROM PUBLIC, anon;
