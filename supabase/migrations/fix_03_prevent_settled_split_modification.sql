CREATE OR REPLACE FUNCTION public.prevent_settled_split_modification()
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
