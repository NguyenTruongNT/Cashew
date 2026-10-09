// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG DỮ LIỆU: ĐỊNH NGHĨA BẢNG & THỰC THỂ (TABLES)]
// File: lib/database/tables.dart
// Mô tả: Định nghĩa cấu trúc các bảng dữ liệu (Schema) và các trường
// tương ứng với hệ thống SQLite theo kiến trúc lưu trữ của Cashew.
// Bao gồm các bảng phục vụ cơ chế Offline-First:
//   - documents   : metadata tài liệu + cột đồng bộ (checksum, version...)
//   - delete_logs : nhật ký xóa mềm (tombstone) để đồng bộ xóa 2 chiều
//   - sync_outbox : hàng đợi thao tác cục bộ chờ đẩy lên Cloud
//   - sync_state  : lưu mốc thời gian đồng bộ gần nhất (lastSyncAt)
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
  static const String colOwnerId = 'owner_id';

  /// Câu lệnh SQL tạo bảng Môn học
  static const String createTableSql =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colName TEXT NOT NULL,
      $colCode TEXT NOT NULL,
      $colColor INTEGER NOT NULL,
      $colIcon TEXT NOT NULL,
      $colCreatedDate INTEGER NOT NULL,
      $colOwnerId TEXT NOT NULL DEFAULT 'local'
    );
  ''';

  static const String createOwnerIndexSql =
      'CREATE INDEX IF NOT EXISTS idx_subjects_owner ON $tableName ($colOwnerId);';
}

/// Định nghĩa tên bảng và các cột của bảng Tài liệu học tập (Documents)
class DocumentTable {
  static const String tableName = 'documents';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colSubjectId = 'subject_id';
  static const String colType =
      'type'; // 'lecture', 'assignment', 'reference', 'exam'
  static const String colNotes = 'notes';
  static const String colFileUrl = 'file_url';
  static const String colStoragePath = 'storage_path';
  static const String colTags = 'tags';
  static const String colStatus =
      'status'; // 'pending', 'inProgress', 'completed'
  static const String colPriority = 'priority'; // 0: Low, 1: Medium, 2: High
  static const String colIsFavorite = 'is_favorite'; // 0 hoặc 1
  static const String colDeadline =
      'deadline'; // Milliseconds since epoch hoặc null
  static const String colCreatedDate = 'created_date';
  static const String colUpdatedDate = 'updated_date';
  static const String colOwnerId = 'owner_id';

  // -------- Các cột phục vụ đồng bộ Offline-First (schema v3) --------
  static const String colChecksum = 'checksum'; // MD5/SHA-256 của tệp đính kèm
  static const String colChecksumAlgo = 'checksum_algo'; // 'md5' | 'sha256'
  static const String colVersion = 'version'; // Số phiên bản tăng dần khi sửa
  static const String colSyncStatus =
      'sync_status'; // synced|pendingUpload|pendingDelete|conflict|localOnly
  static const String colIsDeleted =
      'is_deleted'; // 0/1 - xóa mềm (tombstone cục bộ)
  static const String colLocalPath =
      'local_path'; // Đường dẫn tệp cache cục bộ khi Offline
  static const String colRemoteUpdatedAt =
      'remote_updated_at'; // Thời điểm cập nhật trên Cloud
  static const String colLastSyncedAt =
      'last_synced_at'; // Lần đồng bộ gần nhất với Cloud

  /// Câu lệnh SQL tạo bảng Tài liệu
  static const String createTableSql =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colTitle TEXT NOT NULL,
      $colSubjectId TEXT NOT NULL,
      $colType TEXT NOT NULL,
      $colNotes TEXT,
      $colFileUrl TEXT,
      $colStoragePath TEXT,
      $colTags TEXT,
      $colStatus TEXT NOT NULL DEFAULT 'pending',
      $colPriority INTEGER NOT NULL DEFAULT 1,
      $colIsFavorite INTEGER NOT NULL DEFAULT 0,
      $colDeadline INTEGER,
      $colCreatedDate INTEGER NOT NULL,
      $colUpdatedDate INTEGER NOT NULL,

      $colChecksum TEXT,
      $colChecksumAlgo TEXT NOT NULL DEFAULT 'sha256',
      $colVersion INTEGER NOT NULL DEFAULT 1,
      $colSyncStatus TEXT NOT NULL DEFAULT 'localOnly',
      $colIsDeleted INTEGER NOT NULL DEFAULT 0,
      $colLocalPath TEXT,
      $colRemoteUpdatedAt INTEGER,
      $colLastSyncedAt INTEGER,
      $colOwnerId TEXT NOT NULL DEFAULT 'local',

      FOREIGN KEY ($colSubjectId) REFERENCES ${SubjectTable.tableName} (${SubjectTable.colId}) ON DELETE CASCADE
    );
  ''';

  static const String createOwnerIndexSql =
      'CREATE INDEX IF NOT EXISTS idx_documents_owner ON $tableName ($colOwnerId);';

  /// Danh sách cột đồng bộ cần thêm khi nâng cấp từ schema v2 -> v3
  static const List<String> syncColumns = [
    '$colChecksum TEXT',
    "$colChecksumAlgo TEXT NOT NULL DEFAULT 'sha256'",
    '$colVersion INTEGER NOT NULL DEFAULT 1',
    "$colSyncStatus TEXT NOT NULL DEFAULT 'localOnly'",
    '$colIsDeleted INTEGER NOT NULL DEFAULT 0',
    '$colLocalPath TEXT',
    '$colRemoteUpdatedAt INTEGER',
    '$colLastSyncedAt INTEGER',
  ];
}

/// Bảng nhật ký xóa (delete_logs): lưu tombstone các tài liệu đã xóa
/// để đồng bộ thao tác xóa lên Cloud và tránh "hồi sinh" dữ liệu khi Pull.
class DeleteLogTable {
  static const String tableName = 'delete_logs';

  static const String colId = 'id';
  static const String colDocumentId = 'document_id';
  static const String colOwnerId = 'owner_id';
  static const String colStoragePath = 'storage_path';
  static const String colChecksum = 'checksum';
  static const String colDeletedAt = 'deleted_at';
  static const String colSource = 'source'; // 'local' | 'remote'
  static const String colSyncStatus =
      'sync_status'; // 'pending' | 'synced' | 'failed'
  static const String colRemoteUpdatedAt = 'remote_updated_at';
  static const String colRetryCount = 'retry_count';
  static const String colLastError = 'last_error';

  static const String createTableSql =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colDocumentId TEXT NOT NULL,
      $colOwnerId TEXT,
      $colStoragePath TEXT,
      $colChecksum TEXT,
      $colDeletedAt INTEGER NOT NULL,
      $colSource TEXT NOT NULL DEFAULT 'local',
      $colSyncStatus TEXT NOT NULL DEFAULT 'pending',
      $colRemoteUpdatedAt INTEGER,
      $colRetryCount INTEGER NOT NULL DEFAULT 0,
      $colLastError TEXT
    );
  ''';
}

/// Bảng hàng đợi đồng bộ (sync_outbox): các thao tác cục bộ chờ đẩy lên Cloud.
class SyncOutboxTable {
  static const String tableName = 'sync_outbox';

  static const String colId = 'id';
  static const String colEntityType = 'entity_type'; // 'document'
  static const String colEntityId = 'entity_id';
  static const String colOperation = 'operation'; // 'upsert' | 'delete'
  static const String colPayload =
      'payload'; // JSON snapshot tại thời điểm thao tác
  static const String colCreatedAt = 'created_at';
  static const String colRetryCount = 'retry_count';
  static const String colLastError = 'last_error';

  static const String createTableSql =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colId TEXT PRIMARY KEY,
      $colEntityType TEXT NOT NULL,
      $colEntityId TEXT NOT NULL,
      $colOperation TEXT NOT NULL,
      $colPayload TEXT,
      $colCreatedAt INTEGER NOT NULL,
      $colRetryCount INTEGER NOT NULL DEFAULT 0,
      $colLastError TEXT
    );
  ''';
}

/// Bảng trạng thái đồng bộ (sync_state): lưu key/value, ví dụ mốc lastSyncAt.
class SyncStateTable {
  static const String tableName = 'sync_state';

  static const String colKey = 'state_key';
  static const String colValue = 'state_value';
  static const String colUpdatedAt = 'updated_at';

  static const String createTableSql =
      '''
    CREATE TABLE IF NOT EXISTS $tableName (
      $colKey TEXT PRIMARY KEY,
      $colValue TEXT,
      $colUpdatedAt INTEGER NOT NULL
    );
  ''';

  /// Khóa lưu mốc thời gian đồng bộ gần nhất (dạng millisecondsSinceEpoch).
  static const String keyLastSyncAt = 'last_sync_at';
}
