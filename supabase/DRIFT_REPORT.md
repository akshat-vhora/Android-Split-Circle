# Schema Drift Report: Migration Files vs Live Database

Generated: 2026-06-30
Severity: **HIGH** — `supabase db reset` produces a non-functional schema.

---

## 1. Missing Tables (live-only, not in any migration)

| Table | Columns | Purpose |
|-------|---------|---------|
| `notifications` | id (uuid PK), user_id (FK→users.uid), type (text), title (text), body (text?), data (jsonb), is_read (bool), created_at (timestamptz) | Push notifications for events |
| `rate_limits` | id (uuid PK), user_id (FK→auth.users.id), action (text), window_start (timestamptz), count (int) | Server-side rate limiting |

---

## 2. Column Differences (existing tables)

| Table | Migration Has | Live Has | Difference |
|-------|--------------|----------|------------|
| `users` | `avatar_url text` | **Missing** | Column dropped from live |
| `expenses` | `updated_at timestamptz`, `deleted_by uuid`, `deleted_by_requires_deleted_at` check | **Missing all 3** | Columns/constraint dropped from live |
| `expenses` | — | `deleted_at timestamptz` | Present in both (same) |

---

## 3. Foreign Key Differences

| Table | Column | Migration FK Action | Live FK Action |
|-------|--------|-------------------|----------------|
| `expense_splits` | `expense_id` | `ON DELETE RESTRICT` | `ON DELETE CASCADE` |
| `settlements` | `expense_id` | `ON DELETE RESTRICT` | `ON DELETE CASCADE` |

---

## 4. Missing Indexes (live-only)

| Index | Table | Definition |
|-------|-------|-----------|
| `idx_expenses_created_at` | expenses | `btree (created_at DESC)` |
| `idx_expenses_deleted_at` | expenses | `btree (deleted_at) WHERE deleted_at IS NULL` |
| `idx_expenses_paid_created` | expenses | `btree (paid_by, created_at DESC)` |
| `idx_expense_splits_user_expense` | expense_splits | `btree (user_id, expense_id)` |
| `idx_settlements_expense_payer_status` | settlements | `btree (expense_id, payer_user_id, status)` |
| `idx_settlements_expense_status` | settlements | `btree (expense_id, status)` |
| `idx_notifications_user_id` | notifications | `btree (user_id)` |
| `idx_notifications_unread` | notifications | `btree (user_id) WHERE NOT is_read` |
| `idx_notifications_created_at` | notifications | `btree (user_id, created_at DESC)` |
| `idx_rate_limits_lookup` | rate_limits | `btree (user_id, action, window_start DESC)` |

## Indexes in Migration but Absent from Live

| Index | Migration Definition | Notes |
|-------|---------------------|-------|
| `idx_expenses_active_created_at` | `btree(created_at DESC) WHERE deleted_at IS NULL` | Replaced by `idx_expenses_created_at` + `idx_expenses_deleted_at` |
| `idx_settlements_expense` | `btree(expense_id)` | Replaced by composite indexes |

---

## 5. Missing Views (live-only)

| View | Definition Notes |
|------|-----------------|
| `expense_audit_log_view` | Like `expense_ledger_history_view` but includes deleted expenses, adds computed `is_deleted` column |

## View Differences

| View | Migration | Live |
|------|-----------|------|
| `expense_ledger_history_view` | No `WHERE e.deleted_at IS NULL` | **Has** `WHERE e.deleted_at IS NULL AND can_view_expense(e.id)` |
| `friend_balance_view` | CTE name `active_debts` | CTE name `split_debts` |
| `user_balance_view` | Recomputes from CTEs directly | **Reads from `friend_balance_view`** |

---

## 6. Missing RPCs (live-only, 20 functions)

| Function | Args | Purpose |
|----------|------|---------|
| `check_rate_limit` | p_action, p_max_requests, p_window_seconds | Server-side rate limiting with advisory lock |
| `check_ledger_invariants` | — | Returns JSONB array of invariant violations |
| `clear_all_notifications` | — | Deletes all notifications for current user |
| `count_invariant_violations` | — | Wrapper returning violation count |
| `create_notification` | p_user_id, p_type, p_title, p_body, p_data | Insert notification row |
| `delete_notification` | p_notification_id | Delete single notification |
| `get_awaiting_confirmation` | p_auth | Expenses pending payer confirmation |
| `get_expenses_page` | p_auth, p_page, p_page_size, p_tab | Paginated expense list |
| `get_reminder_cooldown` | p_expense_id, p_target_user_id | Seconds until next reminder allowed |
| `get_unread_notification_count` | — | Unread count |
| `get_user_notifications` | p_limit, p_offset | Paginated notification list |
| `mark_all_notifications_read` | — | Bulk mark-read |
| `mark_notification_read` | p_notification_id | Single mark-read |
| `on_friendship_insert` | (trigger) | Creates friend_added notifications |
| `on_settlement_insert` | (trigger) | Creates settlement_requested notification |
| `on_settlement_update` | (trigger) | Creates confirmed/rejected notifications |
| `rls_auto_enable` | (event trigger) | Auto-enables RLS on new tables |
| `send_reminder` (2 overloads) | 1 or 2 args | Sends reminder notifications |
| `find_user_by_unique_id` | p_unique_id | Exists in migration with different body (no auth check) |
| `fuzz_*` (6 functions) | various | Test helpers for fuzz testing |

## RPC Differences (functions in both migration and live)

| Function | Migration | Live |
|----------|-----------|------|
| `create_expense_with_balances` | No rate limit, no notification, no friendship FOR UPDATE | Has all 3 |
| `delete_expense_with_balances` | Sets `deleted_at + deleted_by` | Sets only `deleted_at` |
| `request_settlement` | No rate limit | Has `check_rate_limit('request_settlement', 20, 60)` |
| `confirm_settlement` | No rate limit, combined `NOT FOUND OR deleted_at` check | Has rate limit, separate deleted_at check |
| `reject_settlement` | No rate limit, silent if no requested settlement found | Has rate limit, raises exception |
| `can_view_expense` | SQL language function | plpgsql with explicit auth.uid() variable |
| `remove_friend_secure` | `SELECT ... FROM users WHERE uid IN (...) FOR UPDATE` | `SELECT ... FROM friendships ... FOR UPDATE` |

---

## 7. Missing Triggers (live-only)

| Trigger | Table | Timing | Function |
|---------|-------|--------|----------|
| `trg_friendship_notify` | friendships | AFTER INSERT | `on_friendship_insert()` |
| `trg_settlement_insert_notify` | settlements | AFTER INSERT | `on_settlement_insert()` |
| `trg_settlement_update_notify` | settlements | AFTER UPDATE | `on_settlement_update()` |

## Trigger Differences

| Trigger | Migration | Live |
|---------|-----------|------|
| `prevent_confirmed_settlement_mutation_trigger` | `BEFORE UPDATE` only | `BEFORE DELETE OR UPDATE` |
| `set_expenses_updated_at` | EXISTS (lines 172-175) | **Missing** — no `updated_at` column on expenses |

---

## 8. RLS Policy Differences

| Table | Migration | Live |
|-------|-----------|------|
| `users` | 3 policies (INSERT, SELECT, UPDATE) | 4 policies (same + "Users can view own profile") |
| `notifications` | **No policies** | 3 policies (SELECT, UPDATE, DELETE) |
| `expenses`, `expense_splits`, `settlements`, `friendships` | No block policies | Has "Block direct *" policies (INSERT/UPDATE/DELETE with `false`) |

---

## 9. GRANT / REVOKE Differences

| Object | Migration | Live |
|--------|-----------|------|
| Core RPCs (7) | EXECUTE TO authenticated | EXECUTE TO authenticated |
| Notification RPCs | **None** | EXECUTE TO authenticated (+ many to anon/public unnecessarily) |
| `check_ledger_invariants` | **None** | EXECUTE TO authenticated, anon, public |
| `find_user_by_unique_id` | **None** | EXECUTE TO authenticated |
| `send_reminder` (both) | **None** | EXECUTE TO authenticated, anon, public |
| Tables/Views | SELECT TO authenticated | SELECT TO authenticated (+ many unconventional grants to anon/public) |
| `rate_limits` | **None** | No SELECT granted — only accessible via RPCs |

---

## 10. Missing SECURITY DEFINER Settings

All live RPCs have `SECURITY DEFINER SET search_path = public`. Migration has the same for most functions but `prevent_confirmed_settlement_mutation()` is `SECURITY INVOKER` on live (migration has `SECURITY DEFINER`).

---

## Summary

| Category | Count |
|----------|-------|
| Missing tables | 2 |
| Missing columns (dropped from live) | 4 |
| Column constraint differences | 1 |
| FK action differences | 2 |
| Missing indexes | 10 |
| Missing views | 1 |
| View definition differences | 3 |
| Missing RPCs | 20 |
| Modified RPCs | 7 |
| Missing triggers | 3 |
| Modified triggers | 2 |
| RLS policy differences | 5+ |
| Grant differences | 20+ |
