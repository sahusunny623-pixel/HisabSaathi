import test from 'node:test';
import assert from 'node:assert/strict';
import { SyncQueue, SyncStatus } from '../src/sync/sync-queue.js';

const operation = (overrides = {}) => ({
  clientOperationId: 'op-1',
  entityId: 'entity-1',
  operationType: 'create_customer',
  requestHash: 'hash-1',
  payload: { name: 'Ravi' },
  createdAt: '2026-09-25T00:00:00.000Z',
  ...overrides,
});

test('deduplicates the same operation without creating a second queue item', () => {
  const queue = new SyncQueue();
  queue.enqueue(operation());
  const duplicate = queue.enqueue(operation());
  assert.equal(queue.list().length, 1);
  assert.equal(duplicate.status, SyncStatus.LOCAL_PENDING);
});

test('turns idempotency key reuse with different data into a conflict', () => {
  const queue = new SyncQueue();
  queue.enqueue(operation());
  const conflict = queue.enqueue(operation({ requestHash: 'different' }));
  assert.equal(conflict.status, SyncStatus.CONFLICT);
  assert.equal(queue.get('op-1').errorCode, 'IDEMPOTENCY_KEY_REUSED');
});

test('claims retryable work and increments failed retries', () => {
  const queue = new SyncQueue();
  queue.enqueue(operation());
  const [claimed] = queue.claimBatch();
  assert.equal(claimed.status, SyncStatus.SYNCING);
  const failed = queue.markFailed('op-1', 'NETWORK', 'temporarily offline');
  assert.equal(failed.status, SyncStatus.FAILED);
  assert.equal(failed.retryCount, 1);
  assert.equal(queue.claimBatch()[0].status, SyncStatus.SYNCING);
});

test('conflicts are not silently retried', () => {
  const queue = new SyncQueue();
  queue.enqueue(operation());
  queue.claimBatch();
  queue.markConflict('op-1', 'SERVER_CONFLICT', 'history changed');
  assert.deepEqual(queue.claimBatch(), []);
  assert.equal(queue.get('op-1').status, SyncStatus.CONFLICT);
});