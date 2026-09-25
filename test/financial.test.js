import test from 'node:test';
import assert from 'node:assert/strict';
import { applyLedgerBalance, calculateInvoice } from '../src/core/financial.js';

test('calculates partial payment and udhaar in minor units', () => {
  const result = calculateInvoice(
    [{ quantity: 1, unitPriceMinor: 125000 }],
    50000,
  );
  assert.equal(result.subtotalMinor, 125000);
  assert.equal(result.paidMinor, 50000);
  assert.equal(result.creditMinor, 75000);
  assert.equal(result.advanceMinor, 0);
});

test('preserves overpayment as an advance instead of discarding it', () => {
  const result = calculateInvoice(
    [{ quantity: 1, unitPriceMinor: 100000 }],
    125000,
  );
  assert.equal(result.creditMinor, 0);
  assert.equal(result.advanceMinor, 25000);
});

test('reconstructs balance from immutable ledger entries', () => {
  assert.equal(applyLedgerBalance([
    { amountMinor: 125000 },
    { amountMinor: -50000 },
  ]), 75000);
});

test('rejects zero or negative quantities', () => {
  assert.throws(
    () => calculateInvoice([{ quantity: 0, unitPriceMinor: 100 }], 0),
    /quantity must be greater than zero/,
  );
});