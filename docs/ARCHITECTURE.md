# HisabSaathi target architecture

## Source of truth

Supabase PostgreSQL is the production source of truth. Supabase Auth owns
identity and refreshable sessions. Supabase Storage owns payment proof files.
Supabase Edge Functions/RPCs will own privileged financial, subscription,
notification, and admin operations.

The current Express/SQLite/PWA stack is retained as a compatibility surface
only during migration. It must not receive new production business logic.

## Tenant model

- A shop is a tenant.
- A profile is a Supabase Auth user.
- `shop_memberships` maps users to shops and carries owner/manager/staff RBAC.
- Every tenant-owned table carries `shop_id`.
- Every tenant table has RLS.
- Server functions derive authorization from `auth.uid()` and membership, not
  from a client-provided trusted shop id.

## Client

The intended client is Flutter/Dart under `mobile/`.

Startup order:

1. Open the local SQLite database.
2. Render cached records and the last known state.
3. Restore the Supabase Auth session.
4. Run sync in the background when connectivity permits.
5. Replace cache entries only with server-authoritative data.

## Financial boundaries

Invoices, payments, ledger entries, and inventory movements are separate
records. A future invoice RPC will validate all entity ownership, calculate
prices server-side, insert invoice/items/ledger/inventory records in one
transaction, and use `client_operation_id` for idempotency.

No client may edit a balance field as financial truth. Balance is reconstructed
from ledger history.

## Deliberate non-goals in this phase

- No fake dashboard data.
- No client-side Premium activation.
- No WhatsApp success state without a provider response.
- No migration of SQLite rows without validation and a rollback plan.