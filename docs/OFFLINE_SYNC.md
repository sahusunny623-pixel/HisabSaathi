# Offline-first and synchronization

## Local state

The Flutter client uses SQLite (`sqflite`) for:

- cached records by namespace and record id
- durable sync operations

The browser service worker is not used as the business-data store.

## Queue state machine

`LOCAL_PENDING → SYNCING → SYNCED`

Failures move to `FAILED` with a retry count. Divergent reuse of an
idempotency key or a server-side history conflict moves to `CONFLICT`. A
conflict is visible and is never silently overwritten.

## Server protocol

`accept_sync_operation` validates membership and stores one operation per
`(shop_id, client_operation_id)`. It returns the existing operation for a
duplicate request and marks a hash mismatch as a conflict.

The RPC intentionally does **not** claim that a domain operation was applied.
An Edge Function/worker in the billing and inventory phases will process
accepted operations transactionally and set the server status to `synced`,
`failed`, or `conflict`. Until then the mobile client re-queues an accepted
but unprocessed operation instead of showing false success.

## Required scenario tests

- airplane mode launch and cached dashboard
- create customer/bill/payment offline
- close/reopen with queued work intact
- reconnect and retry
- duplicate sync
- changed-payload idempotency conflict
- network failure and exponential retry policy
- app termination during sync
- concurrent payment conflict