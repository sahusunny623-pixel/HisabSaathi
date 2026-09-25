import 'package:supabase_flutter/supabase_flutter.dart';

import '../local/local_store.dart';

class SyncEngine {
  SyncEngine({
    required LocalStore localStore,
    required SupabaseClient client,
  })  : _localStore = localStore,
        _client = client;

  final LocalStore _localStore;
  final SupabaseClient _client;

  Future<void> syncOnce({required String shopId}) async {
    final batch = await _localStore.claimBatch();
    for (final operation in batch) {
      try {
        final payload = {...operation.payload, 'shop_id': shopId};
        final raw = await _client.rpc(
          'accept_sync_operation',
          params: {
            'operation_id': operation.clientOperationId,
            'target_entity_id': operation.entityId,
            'target_operation_type': operation.operationType,
            'target_payload': payload,
            'target_request_hash': operation.requestHash,
          },
        );
        final remote = _asMap(raw);
        final remoteStatus = remote['status'] as String?;
        if (remoteStatus == 'synced') {
          await _localStore.updateStatus(operation.clientOperationId, synced);
        } else if (remoteStatus == 'conflict') {
          await _localStore.updateStatus(
            operation.clientOperationId,
            conflict,
            errorCode: remote['error_code'] as String?,
            errorMessage: remote['error_message'] as String?,
          );
        } else {
          // The RPC only accepts an operation. A later server processor must
          // apply the domain change before this client can claim SYNCED.
          await _localStore.updateStatus(
            operation.clientOperationId,
            localPending,
          );
        }
      } catch (error) {
        await _localStore.updateStatus(
          operation.clientOperationId,
          failed,
          errorCode: 'SYNC_REQUEST_FAILED',
          errorMessage: error.toString(),
          incrementRetry: true,
        );
      }
    }
    await _reconcileAcceptedOperations();
  }

  Future<void> _reconcileAcceptedOperations() async {
    final operations = await _localStore.listOperationsByStatus(syncing);
    for (final operation in operations) {
      final rows = await _client
          .from('sync_operations')
          .select('status,error_code,error_message')
          .eq('client_operation_id', operation.clientOperationId)
          .limit(1);
      if (rows.isEmpty) continue;
      final remote = rows.first;
      final remoteStatus = remote['status'] as String?;
      if (remoteStatus == 'synced') {
        await _localStore.updateStatus(operation.clientOperationId, synced);
      } else if (remoteStatus == 'conflict') {
        await _localStore.updateStatus(
          operation.clientOperationId,
          conflict,
          errorCode: remote['error_code'] as String?,
          errorMessage: remote['error_message'] as String?,
        );
      } else if (remoteStatus == 'failed') {
        await _localStore.updateStatus(
          operation.clientOperationId,
          failed,
          errorCode: remote['error_code'] as String?,
          errorMessage: remote['error_message'] as String?,
          incrementRetry: true,
        );
      } else {
        await _localStore.updateStatus(
          operation.clientOperationId,
          localPending,
        );
      }
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Unexpected sync RPC response');
  }
}