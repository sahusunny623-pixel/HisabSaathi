# Security model

## Implemented foundation

- Supabase Auth replaces permanent bearer tokens for the mobile client.
- Auth refresh tokens remain in the Supabase Flutter client's secure session
  storage.
- Service-role credentials are never placed in Flutter code or `.env.example`.
- RLS is enabled on all tenant-owned public tables.
- Membership checks use `auth.uid()` and active memberships.
- Payment proof storage is a private bucket with tenant-folder policies.
- Payment claims cannot be updated by the client into an approved state.
- Sync idempotency keys cannot be reused with different request hashes.

## Still required before production cutover

- Edge Function authorization and rate limiting for privileged operations.
- Admin RBAC and audit-log coverage.
- Signed receipt URLs with short expiry.
- File content validation in the claim Edge Function, in addition to bucket
  MIME and size restrictions.
- Webhook signature verification.
- Security tests against a real Supabase project.
- Secret review in Replit Secrets and Git history.

This document does not claim that the application is fully secure.