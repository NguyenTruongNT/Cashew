// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: MÔ HÌNH DỮ LIỆU (SYNC MODELS)]
// File: lib/struct/sync/sync_models.dart
// Mô tả: Các DTO trung gian phục vụ đồng bộ hai chiều:
//  - RemoteDocument : bản ghi tài liệu trên Cloud (không phụ thuộc SQLite).
//  - DeleteLogEntry  : bản ghi tombstone trong bảng delete_logs.
//  - SyncReport      : kết quả 1 phiên đồng bộ (số liệu + hiệu năng truyền tải).
// =====================================================================

import 'sync_status.dart';

/// Chuyển đổi an toàn giá trị ngày tháng (int millis / DateTime / ISO string).
DateTime _dateFrom(dynamic value, {DateTime? fallback}) {
  if (value == null) {
    if (fallback != null) return fallback;
    throw ArgumentError('Thiếu giá trị ngày tháng bắt buộc');
  }
  if (value is DateTime) return _normalizeMs(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.parse(value);
  throw ArgumentError('Không hỗ trợ kiểu ngày tháng: ${value.runtimeType}');
}

DateTime? _dateFromNullable(dynamic value) {
  if (value == null) return null;
  return _dateFrom(value);
}

/// Chuẩn hóa về độ chính xác milliseconds.
///
/// SQLite lưu timestamp dưới dạng millis (đã cắt microseconds), nên để so sánh
/// Last-Write-Wins và bộ lọc `since` nhất quán giữa Local và Cloud, mọi DTO
/// phải cùng một độ chính xác. Nếu không, một bản có microseconds sẽ luôn
/// "mới hơn" bản đã lưu (millis) và bị kéo/ghi lại vô hạn.
DateTime _normalizeMs(DateTime dt) =>
    DateTime.fromMillisecondsSinceEpoch(dt.millisecondsSinceEpoch);

/// Bản ghi tài liệu được lưu trữ trên Cloud (Firestore).
class RemoteDocument {
  final String id;
  final String title;
  final String subjectId;
  final String type; // DocumentType.nameString
  final String notes;
  final String fileUrl;
  final List<String> tags;
  final String status; // DocumentStatus.nameString
  final int priority;
  final bool isFavorite;
  final DateTime? deadline;
  final DateTime createdDate;
  final DateTime updatedDate;

  // Metadata tệp + phiên bản phía Cloud
  final String? checksum;
  final int? fileSize;
  final int remoteVersion;
  final bool deleted;

  RemoteDocument({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.type,
    this.notes = '',
    this.fileUrl = '',
    this.tags = const [],
    this.status = 'pending',
    this.priority = 1,
    this.isFavorite = false,
    DateTime? deadline,
    required DateTime createdDate,
    required DateTime updatedDate,
    this.checksum,
    this.fileSize,
    this.remoteVersion = 0,
    this.deleted = false,
  })  : createdDate = _normalizeMs(createdDate),
        updatedDate = _normalizeMs(updatedDate),
        deadline = deadline == null ? null : _normalizeMs(deadline);

  RemoteDocument copyWith({
    String? id,
    String? title,
    String? subjectId,
    String? type,
    String? notes,
    String? fileUrl,
    List<String>? tags,
    String? status,
    int? priority,
    bool? isFavorite,
    DateTime? deadline,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? checksum,
    int? fileSize,
    int? remoteVersion,
    bool? deleted,
  }) {
    return RemoteDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      fileUrl: fileUrl ?? this.fileUrl,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isFavorite: isFavorite ?? this.isFavorite,
      deadline: deadline ?? this.deadline,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      checksum: checksum ?? this.checksum,
      fileSize: fileSize ?? this.fileSize,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject_id': subjectId,
      'type': type,
      'notes': notes,
      'file_url': fileUrl,
      'tags': tags,
      'status': status,
      'priority': priority,
      'is_favorite': isFavorite,
      'deadline': deadline?.millisecondsSinceEpoch,
      'created_date': createdDate.millisecondsSinceEpoch,
      'updated_date': updatedDate.millisecondsSinceEpoch,
      'checksum': checksum,
      'file_size': fileSize,
      'remote_version': remoteVersion,
      'deleted': deleted,
    };
  }

  factory RemoteDocument.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : (rawTags is String && rawTags.isNotEmpty
            ? rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[]);

    return RemoteDocument(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      subjectId: map['subject_id'] as String? ?? '',
      type: map['type'] as String? ?? 'lecture',
      notes: map['notes'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? '',
      tags: tags,
      status: map['status'] as String? ?? 'pending',
      priority: (map['priority'] as int? ?? 1).clamp(0, 2),
      isFavorite: map['is_favorite'] == true || map['is_favorite'] == 1,
      deadline: _dateFromNullable(map['deadline']),
      createdDate: _dateFrom(map['created_date'], fallback: DateTime.fromMillisecondsSinceEpoch(0)),
      updatedDate: _dateFrom(map['updated_date'], fallback: DateTime.fromMillisecondsSinceEpoch(0)),
      checksum: map['checksum'] as String?,
      fileSize: map['file_size'] as int?,
      remoteVersion: map['remote_version'] as int? ?? 0,
      deleted: map['deleted'] == true || map['deleted'] == 1,
    );
  }

  /// Chuyển sang Map thô dùng cho tầng lưu trữ Cloud (không chứa field nội bộ).
  Map<String, dynamic> toCloudMap() {
    final map = toMap();
    map.remove('remote_version');
    return map;
  }
}

/// Bản ghi tombstone cho thao tác xóa, lưu trong bảng `delete_logs`.
///
/// Việc lưu vết xóa giúp đồng bộ hai chiều không "hồi sinh" tài liệu đã xóa
/// và cho phép dọn dẹp tệp tương ứng trên Cloud (remote purge).
class DeleteLogEntry {
  final String id;
  final String documentId;
  final DateTime deletedAt;
  final String deviceId;
  final bool synced;
  final String? checksum;
  final DateTime? remotePurgedAt;

  DeleteLogEntry({
    required this.id,
    required this.documentId,
    required DateTime deletedAt,
    this.deviceId = 'local-device',
    this.synced = false,
    this.checksum,
    DateTime? remotePurgedAt,
  })  : deletedAt = _normalizeMs(deletedAt),
        remotePurgedAt = remotePurgedAt == null ? null : _normalizeMs(remotePurgedAt);

  DeleteLogEntry copyWith({
    String? id,
    String? documentId,
    DateTime? deletedAt,
    String? deviceId,
    bool? synced,
    String? checksum,
    DateTime? remotePurgedAt,
  }) {
    return DeleteLogEntry(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      synced: synced ?? this.synced,
      checksum: checksum ?? this.checksum,
      remotePurgedAt: remotePurgedAt ?? this.remotePurgedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'deleted_at': deletedAt.millisecondsSinceEpoch,
      'device_id': deviceId,
      'synced': synced ? 1 : 0,
      'checksum': checksum,
      'remote_purged_at': remotePurgedAt?.millisecondsSinceEpoch,
    };
  }

  factory DeleteLogEntry.fromMap(Map<String, dynamic> map) {
    return DeleteLogEntry(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      deletedAt: _dateFrom(map['deleted_at']),
      deviceId: map['device_id'] as String? ?? 'local-device',
      synced: (map['synced'] as int? ?? 0) == 1 || map['synced'] == true,
      checksum: map['checksum'] as String?,
      remotePurgedAt: _dateFromNullable(map['remote_purged_at']),
    );
  }
}

/// Báo cáo kết quả của một phiên đồng bộ (phục vụ logging & kiểm thử hiệu năng).
class SyncReport {
  final bool success;
  final bool skippedOffline;
  final String? error;

  final int pushedDocuments;
  final int pulledDocuments;
  final int pushedDeletes;
  final int appliedDeletes;
  final int uploadedFiles;
  final int downloadedFiles;
  final int conflicts;
  final int attempts;

  final int bytesUploaded;
  final int bytesDownloaded;
  final Duration duration;

  SyncReport({
    required this.success,
    this.skippedOffline = false,
    this.error,
    this.pushedDocuments = 0,
    this.pulledDocuments = 0,
    this.pushedDeletes = 0,
    this.appliedDeletes = 0,
    this.uploadedFiles = 0,
    this.downloadedFiles = 0,
    this.conflicts = 0,
    this.attempts = 0,
    this.bytesUploaded = 0,
    this.bytesDownloaded = 0,
    this.duration = Duration.zero,
  });

  int get totalBytes => bytesUploaded + bytesDownloaded;

  /// Thông lượng trung bình (byte/giây) của phiên đồng bộ.
  double get throughputBytesPerSecond {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return totalBytes > 0 ? double.infinity : 0;
    return totalBytes * 1000 / ms;
  }

  factory SyncReport.offline() => SyncReport(success: true, skippedOffline: true);

  factory SyncReport.failure(String error, {Duration duration = Duration.zero, int attempts = 0}) {
    return SyncReport(
      success: false,
      error: error,
      duration: duration,
      attempts: attempts,
    );
  }

  @override
  String toString() {
    if (skippedOffline) return 'SyncReport(offline)';
    return 'SyncReport(success: $success, pushed: $pushedDocuments, pulled: $pulledDocuments, '
        'deletes: $pushedDeletes/$appliedDeletes, files: $uploadedFiles↑/$downloadedFiles↓, '
        'bytes: $bytesUploaded↑/$bytesDownloaded↓, in ${duration.inMilliseconds}ms'
        '${error != null ? ', error: $error' : ''})';
  }
}

/// Snapshot trạng thái đồng bộ hiện tại (dùng cho UI/badge sau này).
class SyncState {
  final bool isSyncing;
  final bool online;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final String? lastError;

  const SyncState({
    this.isSyncing = false,
    this.online = true,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastError,
  });

  SyncState copyWith({
    bool? isSyncing,
    bool? online,
    DateTime? lastSyncAt,
    int? pendingCount,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      online: online ?? this.online,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  static const SyncState idle = SyncState();
}

/// Ngoại lệ mạng/Cloud dùng để kích hoạt cơ chế retry khi mạng yếu.
class SyncNetworkException implements Exception {
  final String message;
  final bool transient;

  SyncNetworkException(this.message, {this.transient = true});

  @override
  String toString() => 'SyncNetworkException: $message';
}

/// Tiện ích nội bộ: giá trị SyncStatus mặc định cho dữ liệu đến từ Cloud.
SyncStatus remoteSyncStatus() => SyncStatus.synced;
