import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

const localPending = 'LOCAL_PENDING';
const syncing = 'SYNCING';
const synced = 'SYNCED';
const failed = 'FAILED';
const conflict = 'CONFLICT';

class SyncRecord {
  const SyncRecord({
    required this.clientOperationId,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.requestHash,
    this.status = localPending,
    this.retryCount = 0,
    this.createdAt,
    this.errorCode,
    this.errorMessage,
  });

  final String clientOperationId;
  final String entityId;
  final String operationType;
  final Map<String, dynamic> payload;
  final String requestHash;
  final String status;
  final int retryCount;
  final DateTime? createdAt;
  final String? errorCode;
  final String? errorMessage;

  Map<String, Object?> toRow() => {
        'client_operation_id': clientOperationId,
        'entity_id': entityId,
        'operation_type': operationType,
        'payload': jsonEncode(payload),
        'request_hash': requestHash,
        'status': status,
        'retry_count': retryCount,
        'created_at': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
        'error_code': errorCode,
        'error_message': errorMessage,
      };

  factory SyncRecord.fromRow(Map<String, Object?> row) {
    return SyncRecord(
      clientOperationId: row['client_operation_id']! as String,
      entityId: row['entity_id']! as String,
      operationType: row['operation_type']! as String,
      payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
      requestHash: row['request_hash']! as String,
      status: row['status']! as String,
      retryCount: row['retry_count']! as int,
      createdAt: DateTime.parse(row['created_at']! as String),
      errorCode: row['error_code'] as String?,
      errorMessage: row['error_message'] as String?,
    );
  }
}

class LocalStore {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = path.join(await getDatabasesPath(), 'hisabsaathi.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          create table cache_records (
            namespace text not null,
            record_id text not null,
            payload text not null,
            updated_at text not null,
            primary key (namespace, record_id)
          )
        ''');
        await db.execute('''
          create table sync_queue (
            client_operation_id text primary key,
            entity_id text not null,
            operation_type text not null,
            payload text not null,
            request_hash text not null,
            status text not null,
            retry_count integer not null default 0,
            created_at text not null,
            error_code text,
            error_message text
          )
        ''');
        await db.execute(
          'create index sync_queue_status_created '
          'on sync_queue(status, created_at)',
        );
      },
    );
    return _database!;
  }

  Future<void> cacheRecord({
    required String namespace,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert(
      'cache_records',
      {
        'namespace': namespace,
        'record_id': recordId,
        'payload': jsonEncode(payload),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> readCachedRecords(String namespace) async {
    final db = await database;
    final rows = await db.query(
      'cache_records',
      where: 'namespace = ?',
      whereArgs: [namespace],
      orderBy: 'updated_at desc',
    );
    return rows
        .map((row) => jsonDecode(row['payload']! as String))
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Future<SyncRecord?> findOperation(String clientOperationId) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      where: 'client_operation_id = ?',
      whereArgs: [clientOperationId],
      limit: 1,
    );
    return rows.isEmpty ? null : SyncRecord.fromRow(rows.first);
  }

  Future<SyncRecord> enqueue(SyncRecord record) async {
    final db = await database;
    return db.transaction((txn) async {
      final existingRows = await txn.query(
        'sync_queue',
        where: 'client_operation_id = ?',
        whereArgs: [record.clientOperationId],
        limit: 1,
      );
      if (existingRows.isNotEmpty) {
        final existing = SyncRecord.fromRow(existingRows.first);
        if (existing.requestHash != record.requestHash) {
          await txn.update(
            'sync_queue',
            {
              'status': conflict,
              'error_code': 'IDEMPOTENCY_KEY_REUSED',
              'error_message':
                  'The same client operation id was reused with different data.',
            },
            where: 'client_operation_id = ?',
            whereArgs: [record.clientOperationId],
          );
          final conflictedRows = await txn.query(
            'sync_queue',
            where: 'client_operation_id = ?',
            whereArgs: [record.clientOperationId],
            limit: 1,
          );
          return SyncRecord.fromRow(conflictedRows.single);
        }
        return existing;
      }
      await txn.insert('sync_queue', record.toRow());
      return record;
    });
  }

  Future<List<SyncRecord>> claimBatch({int limit = 25}) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'sync_queue',
        where: 'status in (?, ?)',
        whereArgs: [localPending, failed],
        orderBy: 'created_at asc',
        limit: limit,
      );
      final result = <SyncRecord>[];
      for (final row in rows) {
        final id = row['client_operation_id']! as String;
        await txn.update(
          'sync_queue',
          {'status': syncing},
          where: 'client_operation_id = ?',
          whereArgs: [id],
        );
        result.add(SyncRecord.fromRow({...row, 'status': syncing}));
      }
      return result;
    });
  }

  Future<void> updateStatus(
    String clientOperationId,
    String nextStatus, {
    String? errorCode,
    String? errorMessage,
    bool incrementRetry = false,
  }) async {
    final db = await database;
    await db.rawUpdate(
      '''
      update sync_queue
      set status = ?,
          error_code = ?,
          error_message = ?,
          retry_count = retry_count + ?
      where client_operation_id = ?
      ''',
      [
        nextStatus,
        errorCode,
        errorMessage,
        incrementRetry ? 1 : 0,
        clientOperationId,
      ],
    );
  }

  Future<List<SyncRecord>> listOperationsByStatus(String status) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at asc',
    );
    return rows.map(SyncRecord.fromRow).toList();
  }
}