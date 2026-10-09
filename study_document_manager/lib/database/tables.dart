// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG DỮ LIỆU: ĐỊNH NGHĨA BẢNG & THỰC THỂ (TABLES)]
// File: lib/database/tables.dart
// Mô tả: Định nghĩa cấu trúc các bảng dữ liệu (Schema) và các trường
// tương ứng với hệ thống SQLite theo kiến trúc lưu trữ của Cashew.
// =====================================================================

/// Định nghĩa tên bảng và các cột của bảng Môn học (Subjects)
class SubjectTable {
  static const String tableName = 'subjects';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colCode = 'code';
  static const String colColor = 'color';
  static const String colIcon = 'icon';
  static const String colCreatedDate = 'created_date';

  /// Câu lệnh SQL tạo bảng Môn học
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colName TEXT NOT NULL,
      $colCode TEXT NOT NULL,
      $colColor INTEGER NOT NULL,
      $colIcon TEXT NOT NULL,
      $colCreatedDate INTEGER NOT NULL
    );
  ''';
}

/// Định nghĩa tên bảng và các cột của bảng Tài liệu học tập (Documents)
class DocumentTable {
  static const String tableName = 'documents';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colSubjectId = 'subject_id';
  static const String colType = 'type';             // 'lecture', 'assignment', 'reference', 'exam'
  static const String colNotes = 'notes';
  static const String colFileUrl = 'file_url';
  static const String colTags = 'tags';
  static const String colStatus = 'status';         // 'pending', 'inProgress', 'completed'
  static const String colPriority = 'priority';     // 0: Low, 1: Medium, 2: High
  static const String colIsFavorite = 'is_favorite';// 0 hoặc 1
  static const String colDeadline = 'deadline';     // Milliseconds since epoch hoặc null
  static const String colCreatedDate = 'created_date';
  static const String colUpdatedDate = 'updated_date';

  // --- Các cột phục vụ Offline Sync (Local Cache + Cloud) ---
  static const String colSyncStatus = 'sync_status';   // 'synced','pendingCreate','pendingUpdate','pendingDelete'
  static const String colChecksum = 'checksum';        // Checksum MD5/SHA-256 của nội dung tệp
  static const String colFileSize = 'file_size';       // Kích thước tệp (byte)
  static const String colLocalFilePath = 'local_file_path'; // Đường dẫn tệp trong Local Cache
  static const String colRemoteVersion = 'remote_version';  // Phiên bản phía Cloud (LWW)
  static const String colLastSyncedAt = 'last_synced_at';   // Thời điểm đồng bộ gần nhất

  /// Câu lệnh SQL tạo bảng Tài liệu
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colTitle TEXT NOT NULL,
      $colSubjectId TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colNotes TEXT,
      $colFileUrl TEXT,
      $colTags TEXT,
      $colStatus TEXT NOT NULL DEFAULT 'pending',
      $colPriority INTEGER NOT NULL DEFAULT 1,
      $colIsFavorite INTEGER NOT NULL DEFAULT 0,
      $colDeadline INTEGER,
      $colCreatedDate INTEGER NOT NULL,
      $colUpdatedDate INTEGER NOT NULL,
      $colSyncStatus TEXT NOT NULL DEFAULT 'synced',
      $colChecksum TEXT,
      $colFileSize INTEGER,
      $colLocalFilePath TEXT,
      $colRemoteVersion INTEGER NOT NULL DEFAULT 0,
      $colLastSyncedAt INTEGER,
      FOREIGN KEY ($colSubjectId) REFERENCES ${SubjectTable.tableName} (${SubjectTable.colId}) ON DELETE CASCADE
    );
  ''';

  /// Danh sách cột sync bổ sung cho bảng documents ở phiên bản schema 2
  /// (dùng cho câu lệnh ALTER TABLE khi nâng cấp từ v1 lên v2).
  static const List<String> syncColumnsSql = [
    "ALTER TABLE $tableName ADD COLUMN $colSyncStatus TEXT NOT NULL DEFAULT 'synced'",
    "ALTER TABLE $tableName ADD COLUMN $colChecksum TEXT",
    "ALTER TABLE $tableName ADD COLUMN $colFileSize INTEGER",
    "ALTER TABLE $tableName ADD COLUMN $colLocalFilePath TEXT",
    "ALTER TABLE $tableName ADD COLUMN $colRemoteVersion INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE $tableName ADD COLUMN $colLastSyncedAt INTEGER",
  ];
}

/// Định nghĩa bảng Nhật ký xóa (delete_logs) phục vụ đồng bộ tombstone.
///
/// Mỗi lần người dùng xóa tài liệu khi offline, một bản ghi tombstone được
/// tạo ra để khi có mạng trở lại hệ thống biết cần xóa tài liệu/tệp tương ứng
/// trên Cloud, tránh việc đồng bộ ngược làm "hồi sinh" dữ liệu đã xóa.
class DeleteLogTable {
  static const String tableName = 'delete_logs';

  static const String colId = 'id';
  static const String colDocumentId = 'document_id';
  static const String colDeletedAt = 'deleted_at';
  static const String colDeviceId = 'device_id';
  static const String colSynced = 'synced';                 // 0: chờ đẩy, 1: đã đồng bộ
  static const String colChecksum = 'checksum';             // Checksum tệp tại thời điểm xóa
  static const String colRemotePurgedAt = 'remote_purged_at';

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colDocumentId TEXT NOT NULL,
      $colDeletedAt INTEGER NOT NULL,
      $colDeviceId TEXT,
      $colSynced INTEGER NOT NULL DEFAULT 0,
      $colChecksum TEXT,
      $colRemotePurgedAt INTEGER
    );
  ''';
}

/// Bảng metadata nội bộ cho đồng bộ (mốc thời gian kéo dữ liệu gần nhất...).
class SyncMetaTable {
  static const String tableName = 'sync_meta';

  static const String colKey = 'key';
  static const String colValue = 'value';

  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colKey TEXT PRIMARY KEY,
      $colValue TEXT
    );
  ''';
}
