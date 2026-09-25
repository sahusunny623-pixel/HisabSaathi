# HisabSaathi

**Dukaan ka poora hisaab, ek saathi ke saath.**

HisabSaathi is a small-shop management SaaS focused on billing, inventory, customer ledger, udhaar tracking and payment collection.

## Core product
- Simple billing (no GST/tax fields in the bill)
- Customer ledger and udhaar tracking
- Customer phone required for reminder workflows
- Inventory / stock
- Reports and dashboard
- WhatsApp-first payment reminders
- UPI QR / payment collection flow
- Premium subscription: ₹149 for 30 days
- Unique shop Profile ID (`HS-XXXXXXXX`)
- Ad-free experience
- PWA/mobile install support

## Payment verification
A screenshot or UTR claim does **not** automatically activate Premium. Premium is activated only after trusted payment verification by an admin or a compliant payment-provider webhook.

## Architecture migration

The production target is Supabase Auth + PostgreSQL + private Storage, with a
Flutter/Dart mobile client. The initial schema, RLS policies, auth foundation,
SQLite cache, and idempotent sync queue live under:

- `supabase/migrations/`
- `supabase/tests/`
- `mobile/`
- `docs/`

The existing Express/SQLite/PWA stack is retained temporarily so valid legacy
functionality is not removed before replacement and data reconciliation are
complete. It is not the target production source of truth.

## Secrets and configuration

Use Replit Secrets for credentials. `.env.example` contains variable names
only. Never commit Supabase service-role keys, provider tokens, admin secrets,
or webhook secrets.

## Local run
```bash
npm install
npm start
```

The app serves from `web/` and the API from `server/`.

## Tests

```bash
npm test
npm run check
```

Flutter and Supabase integration commands are documented in
`mobile/README.md` and `docs/TEST_PLAN.md`; they require toolchains that are
not installed in the current Replit environment.
