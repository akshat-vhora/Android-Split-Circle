-- Fix set_updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Fix prevent_confirmed_settlement_mutation
CREATE OR REPLACE FUNCTION public.prevent_confirmed_settlement_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF OLD.status = 'confirmed' THEN
    RAISE EXCEPTION 'Confirmed settlements cannot be modified or deleted';
  END IF;
  RETURN OLD;
END;
$$;
