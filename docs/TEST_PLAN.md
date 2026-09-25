# Test plan

## Tests that run in this repository

```bash
npm test
npm run check
git diff --check
```

These cover financial arithmetic, overpayment preservation, ledger
reconstruction, queue idempotency/conflicts, and migration/RLS guardrails.

## Supabase database tests

`supabase/tests/rls.sql` is a pgTAP smoke suite. The required seeded
integration scenario is:

1. Create two Auth users and two shops.
2. Add one membership per shop.
3. Assert Shop A cannot select or mutate Shop B customers, invoices,
   payments, products, or storage objects.
4. Assert a non-member cannot invoke `accept_sync_operation` for either shop.
5. Assert reuse of a client operation id with a different request hash creates
   `CONFLICT`.

These tests require a real Supabase local/project environment and are not
reported as passed in this Replit environment because Supabase CLI is absent.

## Mobile tests

In a Flutter-capable CI runner:

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Add widget tests for the auth gate and integration tests for the SQLite queue
before enabling the mobile release pipeline.

## Release gates

No phase is complete until its unit tests pass. No production cutover is
complete until the real Supabase RLS, storage, auth, financial transaction,
offline recovery, and migration tests pass.