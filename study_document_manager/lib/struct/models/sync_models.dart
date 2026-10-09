// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG DỮ LIỆU: MÔ HÌNH PHỤC VỤ ĐỒNG BỘ (SYNC MODELS)]
// File: lib/struct/models/sync_models.dart
// Mô tả: Định nghĩa các entity phục vụ cơ chế Offline-First:
//   - DeleteLogModel   : bản ghi tombstone trong bảng delete_logs
//   - SyncOutboxEntry  : một thao tác cục bộ đang chờ đồng bộ lên Cloud
// =====================================================================

import 'dart:convert';

/// Trạng thái đồng bộ của một bản ghi trong delete_logs.
enum DeleteLogStatus {
  pending,
  synced,
  failed;

  String get nameString {
    switch (this) {
      case DeleteLogStatus.pending:
        return 'pending';
      case DeleteLogStatus.synced:
        return 'synced';
      case DeleteLogStatus.failed:
        return 'failed';
    }
  }

  static DeleteLogStatus fromString(String? val) {
    switch (val) {
      case 'synced':
        return DeleteLogStatus.synced;
      case 'failed':
        return DeleteLogStatus.failed;
      case 'pending':
      default:
        return DeleteLogStatus.pending;
    }
  }
}

/// Loại thao tác trong hàng đợi đồng bộ.
enum SyncOperation {
  upsert,
  delete;

  String get nameString => name;

  static SyncOperation fromString(String? val) {
    return val == 'delete' ? SyncOperation.delete : SyncOperation.upsert;
  }
}

/// Bản ghi nhật ký xóa (tombstone) — bảng `delete_logs`.
class DeleteLogModel {
  final String id;
  final String documentId;
  final String? ownerId;
  final String? storagePath;
  final String? checksum;
  final DateTime deletedAt;
  final String source; // 'local' | 'remote'
  final DeleteLogStatus syncStatus;
  final DateTime? remoteUpdatedAt;
  final int retryCount;
  final String? lastError;

  DeleteLogModel({
    required this.id,
    required this.documentId,
    this.ownerId,
    this.storagePath,
    this.checksum,
    required this.deletedAt,
    this.source = 'local',
    this.syncStatus = DeleteLogStatus.pending,
    this.remoteUpdatedAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'owner_id': ownerId,
      'storage_path': storagePath,
      'checksum': checksum,
      'deleted_at': deletedAt.millisecondsSinceEpoch,
      'source': source,
      'sync_status': syncStatus.nameString,
      'remote_updated_at': remoteUpdatedAt?.millisecondsSinceEpoch,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory DeleteLogModel.fromMap(Map<String, dynamic> map) {
    return DeleteLogModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      ownerId: map['owner_id'] as String?,
      storagePath: map['storage_path'] as String?,
      checksum: map['checksum'] as String?,
      deletedAt: DateTime.fromMillisecondsSinceEpoch(map['deleted_at'] as int),
      source: map['source'] as String? ?? 'local',
      syncStatus: DeleteLogStatus.fromString(map['sync_status'] as String?),
      remoteUpdatedAt: map['remote_updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['remote_updated_at'] as int)
          : null,
      retryCount: (map['retry_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  DeleteLogModel copyWith({
    DeleteLogStatus? syncStatus,
    DateTime? remoteUpdatedAt,
    int? retryCount,
    String? lastError,
  }) {
    return DeleteLogModel(
      id: id,
      documentId: documentId,
      ownerId: ownerId,
      storagePath: storagePath,
      checksum: checksum,
      deletedAt: deletedAt,
      source: source,
      syncStatus: syncStatus ?? this.syncStatus,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Một thao tác cục bộ trong hàng đợi `sync_outbox`.
class SyncOutboxEntry {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  SyncOutboxEntry({
    required this.id,
    this.entityType = 'document',
    required this.entityId,
    required this.operation,
    this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation.nameString,
      'payload': payload == null ? null : jsonEncode(payload),
      'created_at': createdAt.millisecondsSinceEpoch,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory SyncOutboxEntry.fromMap(Map<String, dynamic> map) {
    return SyncOutboxEntry(
      id: map['id'] as String,
      entityType: map['entity_type'] as String? ?? 'document',
      entityId: map['entity_id'] as String,
      operation: SyncOperation.fromString(map['operation'] as String?),
      payload: _decodePayload(map['payload'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      retryCount: (map['retry_count'] as int?) ?? 0,
      lastError: map['last_error'] as String?,
    );
  }
}

// ---------------------------------------------------------------------
// Tiện ích JSON nội bộ (tránh phụ thuộc vòng vào tầng khác)
// ---------------------------------------------------------------------
Map<String, dynamic>? _decodePayload(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
