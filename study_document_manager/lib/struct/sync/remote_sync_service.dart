// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: DỊCH VỤ CLOUD TỪ XA (REMOTE SYNC)]
// File: lib/struct/sync/remote_sync_service.dart
// Mô tả: Trừu tượng hóa nguồn dữ liệu Cloud để SyncEngine làm việc độc lập
// với nhà cung cấp cụ thể. Cài đặt thực tế (Firebase Storage/Firestore,
// AWS S3, REST API...) chỉ cần hiện thực interface này. Bản Mock phục vụ
// kiểm thử và mô phỏng mạng yếu nằm ở `mock_remote_sync_service.dart`.
// =====================================================================

import '../models/document_models.dart';

/// Đối tượng tài liệu ở phía Cloud (kèm metadata phục vụ đồng bộ).
class RemoteDocument {
  final String id;
  final String ownerId;
  final int version;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? checksum;
  final String checksumAlgorithm;
  final String? storagePath;

  /// Toàn bộ metadata tài liệu (tương thích DocumentModel.toMap()).
  final Map<String, dynamic> data;

  const RemoteDocument({
    required this.id,
    required this.ownerId,
    required this.version,
    required this.updatedAt,
    required this.data,
    this.isDeleted = false,
    this.checksum,
    this.checksumAlgorithm = 'sha256',
    this.storagePath,
  });

  factory RemoteDocument.fromDocument(DocumentModel doc, String ownerId) {
    return RemoteDocument(
      id: doc.id,
      ownerId: ownerId,
      version: doc.version,
      updatedAt: doc.updatedDate,
      data: doc.toMap(),
      isDeleted: doc.isDeleted,
      checksum: doc.checksum,
      checksumAlgorithm: doc.checksumAlgorithm,
      storagePath: doc.storagePath,
    );
  }

  /// Chuyển về DocumentModel cục bộ (mặc định đánh dấu đã đồng bộ).
  DocumentModel toLocalDocument({SyncStatus status = SyncStatus.synced}) {
    final local = DocumentModel.fromMap(data);
    return local.copyWith(
      syncStatus: status,
      version: version,
      remoteUpdatedAt: updatedAt,
      lastSyncedAt: DateTime.now(),
      isDeleted: isDeleted,
      updatedDate: local.updatedDate,
    );
  }

  RemoteDocument copyWith({
    int? version,
    DateTime? updatedAt,
    bool? isDeleted,
    String? checksum,
    String? checksumAlgorithm,
    String? storagePath,
    Map<String, dynamic>? data,
  }) {
    return RemoteDocument(
      id: id,
      ownerId: ownerId,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      data: data ?? this.data,
      isDeleted: isDeleted ?? this.isDeleted,
      checksum: checksum ?? this.checksum,
      checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
      storagePath: storagePath ?? this.storagePath,
    );
  }
}

/// Xung đột phiên bản khi đẩy dữ liệu lên Cloud.
class RemoteConflictException implements Exception {
  final RemoteDocument remote;

  const RemoteConflictException(this.remote);

  @override
  String toString() =>
      'RemoteConflictException(id=${remote.id}, remoteVersion=${remote.version})';
}

/// Lỗi mạng mô phỏng/không kết nối.
class RemoteNetworkException implements Exception {
  final String message;

  const RemoteNetworkException([this.message = 'Không có kết nối tới Cloud']);

  @override
  String toString() => 'RemoteNetworkException: $message';
}

/// Interface dịch vụ Cloud mà SyncEngine phụ thuộc vào.
abstract class RemoteSyncService {
  /// Kiểm tra khả năng kết nối tới Cloud (dùng cho NetworkMonitor).
  Future<bool> ping();

  /// Lấy thời gian phía server (chống lệch đồng hồ thiết bị).
  Future<DateTime> serverTime();

  /// Liệt kê các thay đổi trên Cloud kể từ mốc [since].
  Future<List<RemoteDocument>> pullChanges({
    required String ownerId,
    DateTime? since,
  });

  /// Đẩy (upsert) một tài liệu lên Cloud; trả về bản canonical.
  /// Ném [RemoteConflictException] nếu version trên Cloud mới hơn.
  Future<RemoteDocument> pushDocument(RemoteDocument document);

  /// Xóa một tài liệu trên Cloud.
  Future<void> deleteRemoteDocument({
    required String ownerId,
    required String documentId,
    String? storagePath,
  });

  /// Tải nội dung tệp lên Cloud; trả về storagePath.
  Future<String> uploadFile({
    required String ownerId,
    required String documentId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  });

  /// Tải nội dung tệp từ Cloud theo storagePath.
  Future<List<int>?> downloadFile({
    required String storagePath,
    void Function(double progress)? onProgress,
  });

  /// Xóa tệp trên Cloud.
  Future<void> deleteFile({required String storagePath});
}
