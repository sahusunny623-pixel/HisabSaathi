# Supabase database

## Migration

The initial production migration is:

`supabase/migrations/20260925000000_initial_schema.sql`

It creates:

- identity and tenant tables: `profiles`, `shops`, `shop_memberships`
- catalog and sales: `customers`, `products`, `invoices`, `invoice_items`
- financial history: `payments`, `ledger_entries`
- stock history: `inventory_movements`
- monetization: `subscription_entitlements`, `payment_claims`
- operations: `reminder_jobs`, `sync_operations`, `audit_logs`

Money is stored as integer minor units (`*_minor`), never floating-point
currency values. Quantities use fixed-precision numeric values.

## Invariants

- `invoice.paid_minor + invoice.credit_minor = invoice.subtotal_minor`
- quantities and payment amounts must be positive
- invoice item amount is calculated from quantity and unit price
- `(shop_id, client_operation_id)` is unique for idempotent writes
- UTR is globally unique
- receipt files are private and stored under a tenant folder
- ledger and inventory history are read-only to normal clients

## Applying

Apply this migration only through the connected Supabase project's migration
workflow. Do not point it at Replit's managed database by accident. Verify the
target project and take a backup before applying to a production Supabase
project.