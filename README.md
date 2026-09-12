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

## Production notes
- Configure secrets in `.env`; never commit credentials.
- Use HTTPS in production.
- For multi-instance production, prefer PostgreSQL/object storage over local SQLite/filesystem.
- WhatsApp Cloud API requires valid Meta credentials and approved messaging configuration.
- Configure `UPI_WEBHOOK_SECRET` only when a trusted payment provider webhook is available.

## Local run
```bash
npm install
npm start
```

The app serves from `web/` and the API from `server/`.
