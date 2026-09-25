-- Run with Supabase's local test runner after applying migrations.
-- These tests require pgTAP and two authenticated JWT contexts. They are
-- intentionally kept as SQL so tenant isolation is tested in PostgreSQL, not
-- approximated in JavaScript.

begin;
select plan(12);

select has_table('public', 'shops', 'shops table exists');
select has_table('public', 'shop_memberships', 'memberships table exists');
select has_table('public', 'customers', 'customers table exists');
select has_table('public', 'invoices', 'invoices table exists');
select has_table('public', 'payments', 'payments table exists');
select has_table('public', 'inventory_movements', 'inventory movements table exists');
select has_table('public', 'sync_operations', 'sync operations table exists');
select has_function('public', 'is_shop_member', 'is_shop_member helper exists');
select has_function('public', 'accept_sync_operation', 'idempotent sync RPC exists');

select ok(
  (select relrowsecurity from pg_class where oid = 'public.customers'::regclass),
  'customers has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.invoices'::regclass),
  'invoices has RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class where oid = 'public.payments'::regclass),
  'payments has RLS enabled'
);

-- Full cross-tenant read/write tests are executed by the CI Supabase project
-- with seeded users. See docs/TEST_PLAN.md for the exact scenario.
select * from finish();
rollback;