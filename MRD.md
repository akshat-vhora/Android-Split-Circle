# SplitCircle — Market Requirements Document (MRD)

**Version:** 1.0.0  
**Last Updated:** May 2026  
**Platform:** Android (Flutter)  
**Backend:** Supabase + Firebase Cloud Messaging

---

## 1. Executive Summary

SplitCircle is a mobile-first expense-splitting application that allows users to track shared expenses with friends, manage IOUs, and settle debts. It provides a complete workflow from expense creation through settlement, with real-time notifications, analytics, and QR-based friend discovery. The app is built on Supabase for backend services (PostgreSQL database, authentication, edge functions, and storage) and uses Firebase Cloud Messaging for push notifications.

**Target Users:** Friend groups, roommates, travelers, and anyone who splits expenses regularly.

**Key Value Proposition:** Seamless end-to-end expense management with native Google sign-in, QR code friend discovery, receipt photo capture, sub-item level splitting, and automated settlement tracking.

---

## 2. Market Problem

1. **Manual tracking is error-prone** — relying on mental math, notes apps, or spreadsheets leads to forgotten expenses and disputes.
2. **Existing solutions are fragmented** — many apps only handle basic equal splits and don't support custom amounts, sub-items, or receipt photos.
3. **Settlement friction** — most apps don't provide a clear "request → confirm → settled" workflow for closing debts.
4. **Friend discovery is cumbersome** — typing usernames is slow; QR codes provide instant, error-free friend addition.
5. **No visibility into spending patterns** — users lack insights into their spending by category and month.

---

## 3. Target Audience

| Segment | Description | Primary Use Case |
|---|---|---|
| **Friend Groups** | Social circles sharing meals, outings, trips | Quick expense splitting with equal/custom splits |
| **Roommates** | People living together sharing rent, utilities, groceries | Recurring expenses, settlement tracking |
| **Travelers** | Groups on trips sharing accommodation, transport, food | Multi-currency, receipt capture, sub-item splits |
| **Couples** | Partners managing shared finances | Daily expense tracking, category analytics |

---

## 4. User Personas

### Persona 1: College Student (Aarav)
- **Age:** 22  
- **Behavior:** Eats out with friends 3-4 times a week, splits bills frequently  
- **Pain point:** Tired of calculating who owes what manually  
- **Needs:** Quick expense creation, equal split, easy friend addition via QR  

### Persona 2: Working Professional (Priya)
- **Age:** 29  
- **Behavior:** Lives with 2 roommates, shares rent, groceries, utilities  
- **Pain point:** Tracking monthly shared expenses is chaotic  
- **Needs:** Sub-item splitting for groceries, settlement reminders, monthly analytics  

### Persona 3: Frequent Traveler (Rahul)
- **Age:** 35  
- **Behavior:** Takes 3-4 group trips per year with different sets of friends  
- **Pain point:** Managing expenses across multiple trips and currencies  
- **Needs:** Receipt photos, custom splits, multi-currency support, friend management  

---

## 5. Functional Requirements

### 5.1 Authentication & User Management

| ID | Requirement | Priority |
|---|---|---|
| FR-01 | User shall be able to sign up using email and password | P1 |
| FR-02 | User shall be able to sign in using email and password | P1 |
| FR-03 | User shall be able to sign in using Google OAuth via native Google Sign-In | P1 |
| FR-04 | User shall receive a confirmation email on sign-up | P1 |
| FR-05 | User shall be able to reset their password via email (non-Google users only) | P1 |
| FR-06 | Client-side rate limiting shall prevent brute-force attacks on auth endpoints | P1 |
| FR-07 | On first Google sign-in, user shall be prompted to confirm display name and select preferred currency | P2 |
| FR-08 | User input shall be sanitized (XSS prevention, email normalization) | P1 |

### 5.2 Expense Management

| ID | Requirement | Priority |
|---|---|---|
| FR-09 | User shall be able to create an expense with title, amount, category, date, and optional description | P1 |
| FR-10 | User shall be able to select participants from their friends list | P1 |
| FR-11 | Expense amount shall display in the user's preferred currency with the correct symbol | P1 |
| FR-12 | User shall be able to set a custom date for the expense (backdating support) | P2 |
| FR-13 | User shall be able to split expenses equally among all participants | P1 |
| FR-14 | User shall be able to set custom split amounts for each participant | P1 |
| FR-15 | User shall be able to redistribute split amounts automatically when editing one participant's share | P2 |
| FR-16 | User shall be able to add sub-items (line items) to an expense and assign each to specific participants | P2 |
| FR-17 | Remaining amount after sub-item assignment shall be split equally among all participants | P2 |
| FR-18 | User shall be able to attach a receipt photo to an expense via gallery | P2 |
| FR-19 | User shall be able to view expense details including splits, sub-items, and receipt image | P1 |
| FR-20 | Creator shall be able to delete an expense, which reverses all associated balances | P1 |
| FR-21 | Expense list shall be paginated (20 items per page) with a "Load More" button | P1 |
| FR-22 | Expense list shall support filter chips: All / You Owe / Owes You / Settled | P1 |
| FR-23 | User shall be able to pull-to-refresh on the expense list and home screen | P1 |
| FR-24 | User shall be able to filter expenses by date range | P2 |

### 5.3 Settlement Workflow

| ID | Requirement | Priority |
|---|---|---|
| FR-25 | A participant shall be able to request settlement on their share of an expense | P1 |
| FR-26 | The payer shall be notified when a settlement is requested | P1 |
| FR-27 | The payer shall be able to confirm or reject a settlement request | P1 |
| FR-28 | On confirmation, friend balances shall be updated and the split marked as settled | P1 |
| FR-29 | The settlement status shall persist across app restarts | P1 |
| FR-30 | The payer shall be able to send payment reminders (with 5-minute cooldown) | P2 |
| FR-31 | The awaiting confirmation screen on the home dashboard shall show pending settlements with accept/reject actions | P1 |

### 5.4 Friend Management

| ID | Requirement | Priority |
|---|---|---|
| FR-32 | Each user shall have a unique shareable ID (e.g., `split_a3f9x`) | P1 |
| FR-33 | User shall be able to add friends by searching their unique ID | P1 |
| FR-34 | User shall be able to scan a friend's QR code via camera to add them | P1 |
| FR-35 | User shall be able to upload a QR code image from gallery to add a friend | P2 |
| FR-36 | Friend requests shall be sent, accepted, and declined through a dedicated screen | P1 |
| FR-37 | If two users send each other friend requests, they shall be auto-matched (both become friends) | P2 |
| FR-38 | User shall be able to view their friends list with net balance per friend | P1 |
| FR-39 | User shall be able to remove a friend (only when balance is zero) | P1 |
| FR-40 | User shall be able to view a friend's profile showing their avatar, name, and net balance | P2 |

### 5.5 QR Code Features

| ID | Requirement | Priority |
|---|---|---|
| FR-41 | Every user shall have a QR code encoding their unique ID | P1 |
| FR-42 | User shall be able to share their QR code as an image via the system share sheet | P2 |
| FR-43 | User shall be able to copy their unique ID to clipboard | P1 |
| FR-44 | QR scanning shall work both via live camera and uploaded image | P1 |

### 5.6 Analytics

| ID | Requirement | Priority |
|---|---|---|
| FR-45 | Dashboard shall show summary cards: Total Spent, Total Owed, Total Owe, Net | P2 |
| FR-46 | Monthly bar chart shall show spending over the last 6 months | P2 |
| FR-47 | Category pie chart shall show spending breakdown by expense category | P2 |
| FR-48 | Analytics shall be filterable by date range and category | P2 |

### 5.7 Notifications

| ID | Requirement | Priority |
|---|---|---|
| FR-49 | User shall receive in-app notifications for: new expenses, friend requests, settlement requests, settlement confirmations, expense deletions, and reminders | P1 |
| FR-50 | User shall receive push notifications via Firebase Cloud Messaging for all in-app notification types | P2 |
| FR-51 | Notification screen shall show all notifications with type-specific icons | P1 |
| FR-52 | User shall be able to mark all notifications as read | P1 |
| FR-53 | User shall be able to delete all read notifications | P2 |
| FR-54 | Tapping a notification shall open the relevant screen (deep linking) | P1 |
| FR-55 | Unread notification count shall be indicated on the notification bell icon in the dashboard | P1 |
| FR-56 | A weekly summary reminder notification shall be sent every Monday via cron job | P3 |

### 5.8 Profile & Settings

| ID | Requirement | Priority |
|---|---|---|
| FR-57 | User shall be able to view and edit their display name | P1 |
| FR-58 | User shall be able to change their profile picture (avatar) | P1 |
| FR-59 | User shall be able to view/copy/share their unique ID | P1 |
| FR-60 | User shall be able to view and change their preferred currency | P1 |
| FR-61 | User shall be able to switch between System, Light, and Dark theme | P1 |
| FR-62 | User shall be able to sign out | P1 |

### 5.9 Home Dashboard

| ID | Requirement | Priority |
|---|---|---|
| FR-63 | Dashboard shall display a balance banner showing total owed, total owe, and net balance | P1 |
| FR-64 | Dashboard shall show a "Recent Expenses" tab with the last 10 expenses | P1 |
| FR-65 | Dashboard shall show an "Awaiting Confirmation" tab with pending settlement requests | P1 |
| FR-66 | Dashboard shall have pull-to-refresh on all tabs | P1 |
| FR-67 | Dashboard notification bell shall indicate unread notifications via icon change | P1 |
| FR-68 | Data shall auto-refresh when app returns from background | P2 |

---

## 6. Non-Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| NFR-01 | App shall be built with Flutter targeting Android platform | P1 |
| NFR-02 | Backend shall use Supabase (PostgreSQL, Auth, Storage, Edge Functions) | P1 |
| NFR-03 | All database access shall be protected by Row Level Security (RLS) policies | P1 |
| NFR-04 | The app shall support Material 3 design system with light and dark themes | P1 |
| NFR-05 | App state shall be managed using Riverpod with proper auto-disposal | P1 |
| NFR-06 | Navigation shall use GoRouter with auth-based redirects | P1 |
| NFR-07 | Performance shall allow smooth infinite scrolling with 20 items per page | P1 |
| NFR-08 | App shall handle app lifecycle events and refresh stale data on foreground | P2 |
| NFR-09 | All text inputs shall be sanitized to prevent XSS | P1 |
| NFR-10 | Rate limiting shall be applied to all auth endpoints | P1 |
| NFR-11 | Google Sign-In native flow shall be used (no browser redirects) | P1 |

---

## 7. Database Schema

### Table: `users`

| Column | Type | Description |
|---|---|---|
| `id` | Auto-generated PK | Primary key |
| `uid` | `text` | Supabase Auth UID |
| `display_name` | `text` | Display name |
| `email` | `text` | Email address |
| `unique_id` | `text` (unique) | Shareable ID (`split_xxxxx`) |
| `avatar_url` | `text?` | Avatar public URL |
| `preferred_currency` | `text` | Default: USD |
| `currency_symbol` | `text` | Default: $ |
| `friends` | `text[]` | Array of friend UIDs |
| `friend_requests` | `jsonb` | Array of request objects |
| `total_owed` | `numeric` | Total owed to user |
| `total_owe` | `numeric` | Total user owes |
| `fcm_tokens` | `text[]` | FCM device tokens |
| `created_at` | `timestamptz` | Auto timestamp |
| `updated_at` | `timestamptz` | Auto-updated by trigger |

### Table: `expenses`

| Column | Type | Description |
|---|---|---|
| `id` | Auto-generated PK | Primary key |
| `expense_id` | `text` | App-generated ID |
| `title`, `description` | `text`, `text?` | Expense details |
| `category` | `text` | Category name |
| `total_amount` | `numeric` | Total amount |
| `currency`, `currency_symbol` | `text` | Currency config |
| `paid_by`, `created_by` | `text` | UIDs |
| `is_group_expense` | `bool` | Group flag |
| `split_type` | `text` | equal/custom/subitem |
| `splits` | `jsonb` | Per-participant split details |
| `sub_items` | `jsonb` | Optional sub-items |
| `receipt_image_url` | `text?` | Receipt photo |
| `created_at`, `updated_at` | `timestamptz` | Timestamps |

### Table: `notifications`

| Column | Type | Description |
|---|---|---|
| `id` | Auto-generated PK | Primary key |
| `user_id` | `text` | Recipient UID |
| `title`, `body` | `text`, `text?` | Notification content |
| `type` | `text` | Notification type |
| `route` | `text?` | Deep-link route |
| `reference_id` | `text?` | Related entity ID |
| `read` | `bool` | Read status |
| `created_at` | `timestamptz` | Auto timestamp |

### Table: `friend_balances`

| Column | Type | Description |
|---|---|---|
| `id` | Auto-generated PK | Primary key |
| `user_id` | `text` | User's UID |
| `friend_id` | `text` | Friend's UID |
| `amount` | `numeric` | Net balance |
| `updated_at` | `timestamptz` | Auto timestamp |

Unique constraint on `(user_id, friend_id)`.

---

## 8. Technical Architecture

### Frontend (Flutter)
- **State Management:** Riverpod (Provider, FutureProvider, StreamProvider, NotifierProvider)
- **Routing:** GoRouter with auth redirect guards
- **UI:** Material 3 with custom teal theme
- **Charts:** fl_chart (bar + pie)
- **QR:** mobile_scanner (camera), qr_flutter (generation)

### Backend (Supabase)
- **Database:** PostgreSQL with RLS
- **Auth:** Supabase Auth (email + Google OAuth)
- **Storage:** Supabase Storage (avatars, receipts buckets)
- **Edge Functions:** Deno (weekly reminder cron, FCM push notifications)
- **Cron:** Weekly settlement reminders

### Push Notifications
- Firebase Cloud Messaging via Supabase Edge Function
- FCM v1 HTTP API with service account JWT authentication
- Local notifications as fallback

### Security
- RLS on all 4 tables
- GRANTs for authenticated + anon roles
- Client-side rate limiting
- Input sanitization
- SECURITY DEFINER functions for cross-user operations

---

## 9. User Flow Diagrams

### Primary Flow: Create & Settle Expense
```
Sign In → Home Dashboard → Tap + → 5-Step Wizard
  → Step 1: Title, Amount, Category, Date
  → Step 2: Select Participants
  → Step 3: Optional Sub-Items
  → Step 4: Customize Split
  → Step 5: Review, Add Receipt → Save
→ Participants get notifications
→ Participant requests settlement
→ Payer gets notification → Confirms or Rejects
→ Balances updated, settled ✓
```

### Secondary Flow: Add Friend
```
Profile → Copy/Share Unique ID or QR Code
OR
Friends → Add Friend → Search by ID or Scan QR
→ Send Friend Request
→ Recipient gets notification → Friend Requests Screen → Accept/Decline
→ Both added to each other's friends list
```

---

## 10. Release Criteria

| Criteria | Description |
|---|---|
| **Authentication** | Email sign-up, login, password reset, Google sign-in all functional |
| **Expense CRUD** | Create, view, paginate, filter, delete expenses without errors |
| **Settlement** | Request, confirm, reject settlement with correct balance updates |
| **Friends** | Send, accept, decline requests; QR scan; search by ID |
| **Notifications** | In-app notifications for all 7 types; push delivery working |
| **Analytics** | Charts render with correct data; filters work |
| **Performance** | Lists scroll smoothly with 20+ items |
| **Error Handling** | Graceful error states for network failures, empty states, RLS errors |
| **Security** | RLS policies tested; auth rate limiting active; no sensitive data exposed |

---

## 11. Future Enhancements (Post-MVP)

| Feature | Description | Priority |
|---|---|---|
| **Group Expenses** | Create persistent groups for recurring shared expenses | P3 |
| **Recurring Expenses** | Auto-create expenses on a schedule (e.g., monthly rent) | P3 |
| **Settlement History** | Audit trail of past settlements | P3 |
| **Multi-Currency Support** | Display amounts in each user's preferred currency | P2 |
| **Offline Support** | Local caching via Hive for offline access | P3 |
| **Export Data** | Export expenses as CSV/PDF | P3 |
| **Receipt OCR** | Auto-extract amounts from receipt photos | P4 |
| **Apple Sign-In** | iOS Sign-In with Apple | P3 |
| **Push Notification Deep Links** | Navigate to correct screen when tapping push notification | P1 |
| **Expense Comments** | Discuss expenses within the app | P4 |
