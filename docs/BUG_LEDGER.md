# Bug ledger and migration risks

This is a tracked implementation ledger, not a claim that every item is
already fixed.

| Severity | Finding | Current disposition |
| --- | --- | --- |
| Critical | Permanent shop bearer token is the primary auth model | Supabase Auth foundation added; legacy routes remain until consumers migrate |
| Critical | SQLite/local filesystem are the production data and receipt stores | Supabase/Postgres schema and private storage bucket added; import path remains |
| Critical | Mutable customer credit balance is financial source of truth | New schema uses immutable ledger entries; billing RPCs are a later phase |
| Critical | Legacy invoice creation trusts client prices and is not atomic | Not changed in this phase; new server-side financial RPC is required before cutover |
| High | Legacy admin is a shared header secret | Supabase RBAC model is defined; admin Edge Function is later |
| High | Legacy WhatsApp worker is a hidden process in deployment | Must move to scheduled Supabase jobs before production cutover |
| High | Legacy reminder scheduling is immediate when queued | New reminder job table separates scheduling from sending |
| High | Legacy language list includes Bhojpuri instead of Bodo | Mobile locale catalog is a later phase; do not copy the legacy list |
| Medium | Existing web UI has hardcoded user-facing strings | Localization phase |
| Medium | Existing browser cache does not cache business records | Mobile SQLite foundation added |

## Accepted current limitations

- No Supabase project is connected to this workspace, so the migration has
  not been applied to a live project.
- Flutter and Dart are not installed in this Replit environment, so mobile
  analysis/build has not run here.
- No production credentials were requested or stored.