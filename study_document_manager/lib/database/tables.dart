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
  static const String colStoragePath = 'storage_path';
  static const String colTags = 'tags';
  static const String colStatus = 'status';         // 'pending', 'inProgress', 'completed'
  static const String colPriority = 'priority';     // 0: Low, 1: Medium, 2: High
  static const String colIsFavorite = 'is_favorite';// 0 hoặc 1
  static const String colDeadline = 'deadline';     // Milliseconds since epoch hoặc null
  static const String colCreatedDate = 'created_date';
  static const String colUpdatedDate = 'updated_date';

  /// Câu lệnh SQL tạo bảng Tài liệu
  static const String createTableSql = '''
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
      FOREIGN KEY ($colSubjectId) REFERENCES ${SubjectTable.tableName} (${SubjectTable.colId}) ON DELETE CASCADE
    );
  ''';
}
