export const SyncStatus = Object.freeze({
  LOCAL_PENDING: 'LOCAL_PENDING',
  SYNCING: 'SYNCING',
  SYNCED: 'SYNCED',
  FAILED: 'FAILED',
  CONFLICT: 'CONFLICT',
});

const retryableStatuses = new Set([SyncStatus.LOCAL_PENDING, SyncStatus.FAILED]);

export class SyncQueue {
  #operations = new Map();

  enqueue(operation) {
    if (!operation?.clientOperationId || !operation.operationType || !operation.requestHash) {
      throw new Error('A sync operation needs an id, type, and request hash');
    }
    const existing = this.#operations.get(operation.clientOperationId);
    if (existing) {
      if (existing.requestHash !== operation.requestHash) {
        existing.status = SyncStatus.CONFLICT;
        existing.errorCode = 'IDEMPOTENCY_KEY_REUSED';
        existing.errorMessage = 'The same client operation id was reused with different data.';
        return { ...existing };
      }
      return { ...existing };
    }
    const stored = {
      ...operation,
      status: operation.status ?? SyncStatus.LOCAL_PENDING,
      retryCount: operation.retryCount ?? 0,
      createdAt: operation.createdAt ?? new Date().toISOString(),
    };
    this.#operations.set(stored.clientOperationId, stored);
    return { ...stored };
  }

  claimBatch(limit = 25) {
    if (!Number.isInteger(limit) || limit < 1) throw new Error('Batch size must be positive');
    const batch = [...this.#operations.values()]
      .filter((operation) => retryableStatuses.has(operation.status))
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
      .slice(0, limit);
    for (const operation of batch) {
      operation.status = SyncStatus.SYNCING;
    }
    return batch.map((operation) => ({ ...operation }));
  }

  markSynced(clientOperationId) {
    return this.#transition(clientOperationId, SyncStatus.SYNCED);
  }

  markFailed(clientOperationId, errorCode, errorMessage) {
    const operation = this.#get(clientOperationId);
    operation.status = SyncStatus.FAILED;
    operation.retryCount += 1;
    operation.errorCode = errorCode;
    operation.errorMessage = errorMessage;
    return { ...operation };
  }

  markConflict(clientOperationId, errorCode, errorMessage) {
    const operation = this.#get(clientOperationId);
    operation.status = SyncStatus.CONFLICT;
    operation.errorCode = errorCode;
    operation.errorMessage = errorMessage;
    return { ...operation };
  }

  get(clientOperationId) {
    return { ...this.#get(clientOperationId) };
  }

  list() {
    return [...this.#operations.values()].map((operation) => ({ ...operation }));
  }

  #transition(clientOperationId, status) {
    const operation = this.#get(clientOperationId);
    operation.status = status;
    operation.errorCode = undefined;
    operation.errorMessage = undefined;
    return { ...operation };
  }

  #get(clientOperationId) {
    const operation = this.#operations.get(clientOperationId);
    if (!operation) throw new Error(`Unknown sync operation: ${clientOperationId}`);
    return operation;
  }
}