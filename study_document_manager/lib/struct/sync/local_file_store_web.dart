// =====================================================================
// [LOCAL FILE STORE - BẢN WEB]
// File: lib/struct/sync/local_file_store_web.dart
// Mô tả: Trên Web không có hệ thống tệp ghi trực tiếp, dùng bộ nhớ làm
// cache tạm trong phiên làm việc (offline metadata vẫn lưu SQLite WASM).
// =====================================================================

import 'local_file_store.dart';

/// Tạo LocalFileStore mặc định cho nền tảng Web.
Future<LocalFileStore> createDefaultLocalFileStore() async {
  return InMemoryFileStore();
}
