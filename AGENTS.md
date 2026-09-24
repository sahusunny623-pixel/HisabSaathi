# HisabSaathi Engineering Contract

## Mission
Build HisabSaathi as a production-grade India-first shop-management SaaS. The product must be simple for a small shopkeeper while being reliable enough to become the daily system of record.

## Non-negotiable architecture
- Flutter is the customer mobile client.
- Backend is a separate, server-authoritative service.
- PostgreSQL is the production relational datastore.
- A background worker/queue handles reminders, notifications, reconciliation and scheduled jobs.
- Object storage handles receipts and QR assets.
- Admin is a separate web application with server-side authorization.
- Flutter must never connect directly to PostgreSQL.
- Secrets never belong in the client.

## Product model
- New users start on FREE.
- FREE keeps core bookkeeping usable and may display limited non-intrusive ads.
- PREMIUM is exactly ₹149/month.
- PREMIUM means zero ads everywhere and full premium entitlement.
- Premium purchase must never be represented as a client-only flag.
- Receipt upload/UTR claim never activates Premium without trusted verification.
- Core data remains intact after Premium expires.

## Core modules
Customers, ledger/udhaar, billing, inventory, expenses, calculator, reports, reminders, payment settings, subscriptions, notifications, backup/sync, help/support, settings and admin.

## Collection-first differentiator
The product is not only a digital khata. It is a collection assistant:
- Customer rows visibly show outstanding amount.
- Automatic WhatsApp reminders are premium.
- Reminder messages are personalized.
- The shop QR is uploaded once and reused.
- Payment recording stops future reminders.
- WhatsApp is never marked sent unless the provider actually accepts the message.

## Security
Use defense-in-depth. Never claim the product is “100% hack-proof”.
Backend authorization must validate the authenticated principal, tenant/shop, role and target resource on every protected operation.
Never trust client-supplied role, shop_id, premium=true, payment status, or admin flags.

## UX
Use a clean green/white Material 3 system, 44–48px touch targets, 8px spacing, strong amount hierarchy, simple language and useful loading/empty/error/offline states. No dark patterns.

## Customer-facing bill
Never add GST, CGST, SGST, IGST, HSN, GSTIN, tax rate or taxable value fields.

## External integrations
Provider-dependent features must have truthful setup/error states. Do not fake WhatsApp delivery, payment verification, backup or analytics.

## Changes
Prefer small, testable modules. Do not create duplicate screens or duplicate business logic. Preserve working functionality while migrating toward the production architecture documented in docs/production-architecture.md.
