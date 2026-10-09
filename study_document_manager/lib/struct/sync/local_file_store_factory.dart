// =====================================================================
// [LOCAL FILE STORE - FACTORY CHỌN NỀN TẢNG]
// File: lib/struct/sync/local_file_store_factory.dart
// Mô tả: Chọn bản triển khai LocalFileStore phù hợp nền tảng tại thời
// điểm biên dịch (native dùng hệ thống tệp, web dùng bộ nhớ).
// =====================================================================

import 'local_file_store.dart';
import 'local_file_store_io.dart'
    if (dart.library.js_interop) 'local_file_store_web.dart' as platform;

export 'local_file_store.dart';

/// Tạo LocalFileStore mặc định theo nền tảng hiện tại.
Future<LocalFileStore> createDefaultLocalFileStore() {
  return platform.createDefaultLocalFileStore();
}
