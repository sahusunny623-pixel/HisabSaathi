# Legacy SQLite migration

The SQLite database is not imported automatically. The existing schema contains
mutable balances, client-controlled prices, local receipt paths, and legacy
authentication records that require validation.

## Planned import order

1. Export a read-only SQLite snapshot and record its hash.
2. Validate shops and generate/retain public `HS-XXXXXXXX` ids.
3. Create Auth users through an approved account-recovery flow; never import
   password hashes into Supabase Auth.
4. Import customers and products after shop ownership checks.
5. Convert opening balances into `OPENING_BALANCE` ledger entries.
6. Import invoices, invoice items, and payments into an auditable history.
7. Rebuild inventory from movements and report any stock discrepancy.
8. Import subscription history as claims/entitlements only when evidence is
   sufficient.
9. Compare row counts, totals, and per-shop balances.
10. Keep the source snapshot read-only until reconciliation is accepted.

Invalid rows must be rejected into a review report, not silently coerced.