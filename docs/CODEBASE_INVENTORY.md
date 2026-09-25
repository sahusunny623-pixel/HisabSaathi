# HisabSaathi codebase inventory

## Baseline inspected

The repository at `sahusunny623-pixel/HisabSaathi` was cloned from GitHub at
commit `90ebf4e` (`Add Gupshup WhatsApp provider support`). The baseline is a
Node.js/Express web application with SQLite persistence and a browser PWA.

## Current areas

| Area | Current implementation | Phase status |
| --- | --- | --- |
| HTTP server | `server/index.js`, Express | Legacy compatibility surface |
| Auth | Hashed permanent shop bearer token in `server/auth.js` | Replacement started with Supabase Auth |
| Database | `server/db.js`, `better-sqlite3` | Legacy only; not production source of truth |
| Frontend | `web/index.html`, `web/admin.html` | Existing web/PWA preserved |
| Service worker | `web/sw.js` | Asset caching only; not business-data offline |
| Worker | `server/worker.js` | Legacy reminder worker; not yet moved to Supabase jobs |
| Payments | Manual UPI claim and local receipt path | Replacement schema exists; storage/verification later |
| WhatsApp | Meta/Gupshup code paths | Provider migration later |
| CI/CD | WhatsApp repair workflow only | Flutter/Supabase checks still to add |
| Mobile | None in baseline | `mobile/` Flutter foundation added |
| Supabase | None in baseline | Initial migration and RLS added |
| Tests | No test script in baseline | Node tests and SQL RLS test plan added |

## Non-destructive migration rule

The legacy server is not removed yet. Removing it before mobile flows and
Supabase Edge Functions are validated would remove working functionality and
make data migration unsafe.