# Production checklist

## Foundation complete in this phase

- [x] Supabase schema migration committed
- [x] Tenant RLS policies committed
- [x] Supabase Auth client foundation committed
- [x] SQLite cache and sync queue foundation committed
- [x] Replit secret names documented
- [x] Node tests and syntax checks pass

## Blocking work

- [ ] Apply migration to the intended Supabase project
- [ ] Run real cross-tenant RLS tests
- [ ] Add atomic invoice/payment/inventory RPCs
- [ ] Add sync operation processor
- [ ] Add Flutter CI and pass `flutter analyze`/`flutter test`
- [ ] Add shop onboarding and dashboard using cached data
- [ ] Implement storage upload and signed receipt access
- [ ] Replace legacy auth/admin/payment paths
- [ ] Validate SQLite migration and reconciliation
- [ ] Configure backups, restore drill, RPO, and RTO
- [ ] Run security and performance tests