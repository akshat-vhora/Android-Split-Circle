-- Block direct mutations on expenses (all go through SECURITY DEFINER RPCs)
CREATE POLICY "Block direct insert on expenses"
  ON public.expenses FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct update on expenses"
  ON public.expenses FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY "Block direct delete on expenses"
  ON public.expenses FOR DELETE TO authenticated USING (false);

-- Block direct mutations on expense_splits
CREATE POLICY "Block direct insert on expense_splits"
  ON public.expense_splits FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct update on expense_splits"
  ON public.expense_splits FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY "Block direct delete on expense_splits"
  ON public.expense_splits FOR DELETE TO authenticated USING (false);

-- Block direct mutations on settlements
CREATE POLICY "Block direct insert on settlements"
  ON public.settlements FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct update on settlements"
  ON public.settlements FOR UPDATE TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY "Block direct delete on settlements"
  ON public.settlements FOR DELETE TO authenticated USING (false);

-- Block direct mutations on friendships
CREATE POLICY "Block direct insert on friendships"
  ON public.friendships FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "Block direct delete on friendships"
  ON public.friendships FOR DELETE TO authenticated USING (false);
