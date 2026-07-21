# Split Circle

A Flutter mobile app for splitting expenses and tracking IOUs among friends, powered by Supabase.

## Features

- **Dashboard** — Net balance overview, quick actions (Settle Up, Add Friends, Add Expense), recent and awaiting-confirmation tabs
- **Expense Tracking** — Add expenses with equal, custom, percentage, shares, or sub-item splits
- **Friend Management** — Add friends via QR code or unique ID, view per-friend balances
- **Settlements** — Request, confirm, or reject settlement requests; send reminders
- **Analytics** — Monthly bar chart and category pie chart for spending breakdown
- **Notifications** — Push notifications for friend requests, expenses, settlements, and reminders
- **Auth** — Email/password and Google Sign-In via Supabase Auth
- **Theming** — Dark and light mode with glassmorphic UI

## Tech Stack

- **Flutter** with Riverpod (state management), GoRouter (navigation)
- **Supabase** for auth, database (Postgres), and RPCs
- **Firebase** for Crashlytics and push messaging
- **fl_chart** for analytics charts

## Setup

1. Clone the repo and run `flutter pub get`
2. Copy `.env.example` to `.env` and fill in your Supabase URL and anon key
3. Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) for Firebase
4. Run `supabase start` for local Supabase or link to a remote project
5. Run `flutter run`

## Database

Migrations are in `supabase/migrations/`. Apply them with `supabase db push`.
