import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration = fs.readFileSync(
  new URL('../supabase/migrations/20260925000000_initial_schema.sql', import.meta.url),
  'utf8',
);
const rlsTest = fs.readFileSync(
  new URL('../supabase/tests/rls.sql', import.meta.url),
  'utf8',
);

test('production migration defines the tenant and financial boundaries', () => {
  for (const fragment of [
    'create table public.shops',
    'create table public.shop_memberships',
    'create table public.ledger_entries',
    'create table public.inventory_movements',
    'create table public.sync_operations',
    'create or replace function public.create_shop',
    'create or replace function public.accept_sync_operation',
    'alter table public.customers enable row level security',
    'alter table public.invoices enable row level security',
    'alter table public.payments enable row level security',
    "insert into storage.buckets",
  ]) {
    assert.match(migration, new RegExp(fragment.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'));
  }
});

test('payment claims cannot activate entitlements from a client update policy', () => {
  assert.doesNotMatch(migration, /create policy claims_member_update/i);
  assert.match(migration, /create table public\.subscription_entitlements/i);
});

test('RLS test file covers the core tenant-owned tables', () => {
  assert.match(rlsTest, /customers has RLS enabled/);
  assert.match(rlsTest, /invoices has RLS enabled/);
  assert.match(rlsTest, /payments has RLS enabled/);
});