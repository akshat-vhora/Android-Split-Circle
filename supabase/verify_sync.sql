-- Schema synchronization verification script.
-- Run on the branch AFTER applying 20260630000001_sync_to_production.sql.
-- Compares the branch schema against known production characteristics.

-- 1. TABLE COUNTS
SELECT 'table_count' AS check_name, COUNT(*) AS actual, 7 AS expected
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- 2. EXPECTED TABLES PRESENT
SELECT 'notifications_exists' AS check_name,
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications')::int AS actual,
  1 AS expected;
SELECT 'rate_limits_exists' AS check_name,
  EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'rate_limits')::int AS actual,
  1 AS expected;

-- 3. COLUMNS REMOVED CORRECTLY
SELECT 'avatar_url_dropped' AS check_name,
  (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'avatar_url'))::int AS actual,
  1 AS expected;
SELECT 'updated_at_dropped_expenses' AS check_name,
  (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'expenses' AND column_name = 'updated_at'))::int AS actual,
  1 AS expected;
SELECT 'deleted_by_dropped' AS check_name,
  (NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'expenses' AND column_name = 'deleted_by'))::int AS actual,
  1 AS expected;

-- 4. CONSTRAINTS
SELECT 'deleted_by_constraint_removed' AS check_name,
  (NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.expenses'::regclass AND conname = 'expenses_deleted_by_requires_deleted_at'))::int AS actual,
  1 AS expected;

-- 5. VIEW COUNTS
SELECT 'view_count' AS check_name, COUNT(*)::int AS actual, 5 AS expected
FROM information_schema.views
WHERE table_schema = 'public';

-- 6. TRIGGER COUNTS (non-internal)
SELECT 'trigger_count' AS check_name, COUNT(*)::int AS actual, 9 AS expected
FROM pg_trigger tg
WHERE tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace = 'public'::regnamespace)
  AND NOT tgisinternal;

-- 7. EXPECTED TRIGGERS PRESENT
SELECT 'trg_friendship_notify_exists' AS check_name,
  EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_friendship_notify')::int AS actual,
  1 AS expected;
SELECT 'trg_settlement_insert_notify_exists' AS check_name,
  EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_settlement_insert_notify')::int AS actual,
  1 AS expected;
SELECT 'trg_settlement_update_notify_exists' AS check_name,
  EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_settlement_update_notify')::int AS actual,
  1 AS expected;

-- 8. INDEX COUNTS (excluding PK/UNIQUE constraint indexes)
SELECT 'index_count' AS check_name, COUNT(*)::int AS actual, 21 AS expected
FROM pg_indexes
WHERE schemaname = 'public';

-- 9. RLS POLICIES
SELECT 'rls_enabled_on_notifications' AS check_name,
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.notifications'::regclass)::int AS actual,
  1 AS expected;
SELECT 'rls_enabled_on_rate_limits' AS check_name,
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.rate_limits'::regclass)::int AS actual,
  1 AS expected;

-- 10. DATA PRESERVATION (should report 0 violations)
SELECT 'data_preserved_objects' AS check_name,
  (SELECT COUNT(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind = 'r')::int AS actual,
  (SELECT COUNT(*) FROM pg_class WHERE relnamespace = 'public'::regnamespace AND relkind = 'r')::int AS expected;
