# Competitor-Derived UX and Reliability Requirements

Research target set:
- Khatabook
- OkCredit
- Vyapar
- myBillBook
- Ok Khata
- Credit Debit
- Udhar Khata Book
- CashBook
- Hisab Expert
- Udharbook AI
- other relevant Indian ledger/billing competitors

Use public app-store reviews and official product information as evidence. Do not claim exhaustive review coverage without evidence.

## Recurring positive signals to retain

Users commonly value:
- simple customer entry
- fast khata entry
- easy-to-understand balances
- offline availability
- searchable customer history
- clean dashboards
- backup/sync
- security/app lock
- multilingual support
- reminder convenience
- staff roles where available

HisabSaathi should preserve these strengths without copying proprietary implementation or UI.

## Recurring complaint classes to design against

### Reliability
- freezes/crashes
- slow billing/search
- generic "something went wrong" errors
- updates breaking workflows

Requirement:
- actionable error states
- retry
- local-safe financial writes
- performance instrumentation
- regression tests

### Data integrity
- balance mismatch
- payment mismatch
- stock mismatch
- backup/sync uncertainty
- offline access limitations

Requirement:
- transactional ledger
- integer paise arithmetic
- audit history
- sync state
- conflict handling
- tested restore process

### Ads and subscriptions
- excessive ads
- paid users still seeing ads
- confusing premium boundaries

Requirement:
- frequency capped free ads
- server-authoritative premium entitlement
- zero ad SDK/rendering for Premium
- no hidden paywall after purchase

### Support
- unclear support state
- slow resolution
- lack of ticket status

Requirement:
- in-app ticketing
- OPEN / IN_REVIEW / WAITING_FOR_USER / RESOLVED
- response notifications
- auditable admin actions

### Privacy / permissions
- unnecessary permissions
- concern over background/call behavior
- uncertainty about account safety

Requirement:
- least privilege
- explicit permission rationale
- no unnecessary call/SMS access
- secure sessions
- logout all devices

### Offline / sync
- inability to access old records offline
- weak multi-device sync

Requirement:
- offline-first core workflows
- operation IDs
- safe reconciliation
- visible sync status

### Complexity
- feature bloat
- accounting-heavy UX for small shops

Requirement:
- progressive disclosure
- collection-first home
- simple reports
- advanced options hidden until needed

## Differentiation

HisabSaathi should not try to win through feature count alone.

Primary differentiation:
1. collection-first dashboard
2. personalized automatic WhatsApp reminders
3. one-time reusable shop payment QR
4. transparent ₹149 single premium plan
5. zero ads for verified Premium
6. fast offline core
7. easy data migration/import
8. trustworthy support
9. clean multilingual UX
10. security and tenant isolation by design

## Retention principle

Do not trap users with proprietary lock-in.

Create legitimate switching value through:
- accurate history
- fast search
- automated collection
- saved QR
- templates
- backups
- reports
- migration/import
- exports
- multi-device continuity

User loyalty must come from usefulness and reliability.
