// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: KHO ĐỆM CỤC BỘ (FILE CACHE STORE)]
// File: lib/struct/sync/file_cache_store.dart
// Mô tả: Điểm vào chung cho FileCacheStore. Dùng conditional import để
// chọn bản cài đặt theo nền tảng:
//  - dart:io (Desktop/Android/iOS) -> thư mục thật trên ổ đĩa.
//  - Web                            -> In-Memory (an toàn, không cần dart:io).
// =====================================================================

export 'file_cache_store_base.dart';

import 'file_cache_store_base.dart';
import 'file_cache_store_io.dart' if (dart.library.html) 'file_cache_store_web.dart' as platform;

/// Tạo FileCacheStore cho nền tảng hiện tại với thư mục gốc [rootPath].
///
/// - Desktop & mobile: lưu tệp thật trong [rootPath].
/// - Web: trả về bản In-Memory (rootPath bị bỏ qua).
FileCacheStore createFileCacheStore(String rootPath) {
  return platform.createPlatformFileCacheStore(rootPath);
}