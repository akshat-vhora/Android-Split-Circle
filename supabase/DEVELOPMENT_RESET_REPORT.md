# Development Reset Report

Generated reset SQL:

- `supabase/migrations/20260601172000_development_reset_ledger_schema.sql`

Edge Function delete commands:

```bash
supabase functions delete weekly-reminder
supabase functions delete send-push-notification
```

Storage cleanup commands:

```bash
supabase storage rm ss:///receipts --recursive --linked --experimental
supabase storage rm ss:///avatars --recursive --linked --experimental
```

Dropped obsolete objects:

- Legacy balance table: `friend_balances`
- Notification table: `notifications`
- Temporary backup table: `ledger_migration_backup`
- Legacy/transitional views: `expense_read_view`, `dashboard_totals_admin_view`, `dashboard_totals_view`, `user_balance_view`, `friend_balance_view`
- Legacy balance RPCs: `apply_friend_balance_delta`, `set_friend_balance_rpc`, `delete_friend_balance_rpc`, `adjust_user_totals_rpc`, `update_user_totals_rpc`
- Legacy currency RPC: `update_preferred_currency`
- Legacy friend request RPCs: `add_friend_request`, `accept_friend_request`, `remove_friend_from_user`
- Legacy notification RPC: `insert_notification_rpc`
- Legacy storage buckets/policies for `receipts` and `avatars`

Recreated clean production schema:

- `users`
- `friendships`
- `expenses`
- `expense_splits`
- `settlements`

Financial source of truth:

- `expenses`
- `expense_splits`
- `settlements`

Final views:

- `friend_balance_view`
- `user_balance_view`
- `dashboard_totals_view`
- `expense_ledger_history_view`

Final RPCs:

- `create_expense_with_balances(jsonb)`
- `request_settlement(text, jsonb)`
- `confirm_settlement(text, text)`
- `reject_settlement(text, text)`
- `delete_expense_with_balances(text)`
- `add_friend_secure(text)`
- `remove_friend_secure(text)`

Integrity triggers:

- `validate_expense_split_sum_trigger`
- `validate_expense_total_split_sum_trigger`
- `validate_settlement_amount_trigger`
- `prevent_confirmed_settlement_mutation_trigger`

Removed by design:

- Multi-currency columns and logic
- Group columns and logic
- Cached balance tables/columns
- JSON financial storage
- Notification Edge Function infrastructure
- Receipt/avatar storage infrastructure
