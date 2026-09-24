# HisabSaathi Production Architecture

## Target topology

Flutter Mobile
  -> HTTPS API
  -> Backend Application
  -> PostgreSQL
  -> Redis/queue (recommended)
  -> Background Workers
  -> Object Storage
  -> WhatsApp / Payment / Notification providers

Separate Admin Web App
  -> same secure backend API
  -> admin-only routes and permissions

## Repository target

Move toward a monorepo layout:

apps/
  mobile/           # Flutter
  admin/            # React/Next.js admin console

services/
  api/              # Node.js + TypeScript backend
  worker/           # background jobs

packages/
  contracts/        # shared API schemas/types

infra/
  migrations/
  deployment/
  observability/

The current legacy web + server application must remain functional during migration. Do not break production while introducing the new structure.

## Backend modules

auth
users
shops
customers
ledger
billing
inventory
expenses
payments
reminders
whatsapp
subscriptions
notifications
reports
sync
uploads
support
admin
analytics
audit

Each module should expose controller -> service -> repository boundaries, validation, authorization and tests.

## Database

Production: PostgreSQL.

Important entities:
Users, Shops, Devices, Sessions, Customers, CustomerReminderPreferences, Products, Categories, Bills, BillItems, Payments, LedgerEntries, Expenses, StockMovements, Reminders, ReminderLogs, Notifications, Subscriptions, PaymentClaims, SupportTickets, AdminActions, FeatureFlags, SyncOperations, WhatsAppAccounts, WhatsAppTemplates, WhatsAppJobs, WhatsAppDeliveryEvents, ShopPaymentSettings, QRAssets, Entitlements, AuditLogs.

Every tenant-owned row must have shop_id and backend authorization must enforce ownership.

Money must be stored as integer minor units (paise) or a safe decimal type; never use floating point for financial totals.

## Authentication

Current UX requirement: mobile number entry with no OTP UI.

Security requirements:
- server-managed authenticated sessions/tokens
- secure storage on device
- rotation and expiry
- revoke session
- logout all devices
- suspicious session detection
- rate limiting
- prepare a future OTP/passkey migration path

Do not infer account ownership only from a typed phone number.

## Premium entitlement

States:
FREE
PREMIUM_PENDING_VERIFICATION
PREMIUM_ACTIVE
PREMIUM_EXPIRED

Server is authoritative.

After verified payment:
- activate for 30 days
- expose exact expiry
- preserve all data
- remove all ad requests
- allow full premium functionality

The client may cache entitlement for graceful offline UX, but must reconcile with the server whenever connectivity is available.

## Ads

Free users may have limited advertising.

Premium users:
- no ad SDK initialization
- no ad requests
- no ad components
- no ad placeholders
- no interstitials
- no rewarded ads
- no banner/native ads

Use a feature flag and entitlement check. Never put ads inside critical financial workflows.

## Automatic WhatsApp reminders

Use server-side scheduling, not mobile timers.

Reminder job state machine:
PENDING -> PROCESSING -> SENT -> DELIVERED
                    -> FAILED
                    -> CANCELLED / SKIPPED

Eligibility checks:
- customer outstanding balance > minimum
- customer has opted in
- reminder automation enabled
- quiet hours respected
- frequency cap respected
- not already sent for the same event
- customer has not paid
- provider configured

Use idempotency keys and retry/backoff.

Message personalization:
customer_name
outstanding_amount
shop_name
due_date
upi_id

Provider abstraction must support WhatsApp Business Platform/Cloud API or another compliant provider.

## Shop QR

The shop owner uploads one UPI QR in payment settings.

Store securely, validate MIME/size/dimensions, and reuse the active asset in reminder flows and customer payment UI.

Never treat a QR screenshot as payment proof.

## Subscription payment flow

Premium screen
-> dedicated payment page
-> current admin-managed subscription QR
-> ₹149
-> UTR + receipt upload
-> pending verification
-> admin approval or trusted webhook
-> Premium Active for 30 days

Admin controls:
- upload/replace/delete subscription QR
- set UPI ID/name/price
- review claims
- view receipt
- review UTR
- approve/reject
- rejection reason
- audit log

Prevent duplicate UTR claims.

## Offline-first

Local storage for:
- customers
- basic ledger
- calculator
- basic billing
- basic inventory

Sync operations must use unique operation IDs and safe conflict handling.

Financial data is never silently overwritten.

## Observability

Production must have:
- structured logs
- health/readiness checks
- error reporting
- audit logs
- queue metrics
- reminder delivery metrics
- subscription metrics
- backup health

Never log secrets, payment PINs, OTPs or full auth tokens.

## Quality gates

Required automated coverage:
- money calculations
- ledger balance
- tenant isolation
- authorization
- subscription activation
- ad gating
- QR upload
- WhatsApp job idempotency
- reminder cancellation after payment
- offline sync
- payment-claim duplicate detection

E2E:
onboarding -> customer -> udhaar -> payment -> reminder -> premium purchase -> verification -> zero ads -> expiry.
