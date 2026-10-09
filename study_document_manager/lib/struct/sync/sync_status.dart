// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: TRẠNG THÁI ĐỒNG BỘ (SYNC STATUS)]
// File: lib/struct/sync/sync_status.dart
// Mô tả: Định nghĩa trạng thái đồng bộ của một tài liệu trong cơ chế
// Offline-First (Local Cache + Cloud). Được dùng chung bởi cả Model,
// tầng Dữ liệu (SQLite) và tầng Dịch vụ đồng bộ.
// =====================================================================

/// Trạng thái đồng bộ của tài liệu so với Cloud.
enum SyncStatus {
  /// Đã đồng bộ, không có thay đổi cục bộ nào đang chờ.
  synced,

  /// Tài liệu mới được tạo cục bộ, đang chờ đẩy lên Cloud.
  pendingCreate,

  /// Tài liệu đã có trên Cloud nhưng bị sửa cục bộ, chờ đẩy cập nhật.
  pendingUpdate,

  /// Tài liệu bị đánh dấu xóa cục bộ (tombstone), chờ đẩy lệnh xóa.
  pendingDelete,
}

extension SyncStatusExtension on SyncStatus {
  /// Tên lưu xuống SQLite / Cloud.
  String get nameString {
    switch (this) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pendingCreate:
        return 'pendingCreate';
      case SyncStatus.pendingUpdate:
        return 'pendingUpdate';
      case SyncStatus.pendingDelete:
        return 'pendingDelete';
    }
  }

  /// Nhãn hiển thị tiếng Việt (phục vụ UI sau này).
  String get displayName {
    switch (this) {
      case SyncStatus.synced:
        return 'Đã đồng bộ';
      case SyncStatus.pendingCreate:
        return 'Chờ tạo mới';
      case SyncStatus.pendingUpdate:
        return 'Chờ cập nhật';
      case SyncStatus.pendingDelete:
        return 'Chờ xóa';
    }
  }

  /// Có thay đổi cục bộ đang chờ đẩy lên Cloud hay không.
  bool get isPending => this != SyncStatus.synced;

  /// Khôi phục trạng thái từ chuỗi lưu trong DB (an toàn với dữ liệu cũ).
  static SyncStatus fromString(String? val) {
    switch (val) {
      case 'pendingCreate':
        return SyncStatus.pendingCreate;
      case 'pendingUpdate':
        return SyncStatus.pendingUpdate;
      case 'pendingDelete':
        return SyncStatus.pendingDelete;
      case 'synced':
      default:
        return SyncStatus.synced;
    }
  }
}
