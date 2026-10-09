// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: KHO ĐỆM LOCAL FILE (NỀN TẢNG WEB)]
// File: lib/struct/sync/file_cache_store_web.dart
// Mô tả: Trên Web, do không có dart:io, ta dùng bản In-Memory làm Local
// Cache (dữ liệu sống trong phiên làm việc). Bản production có thể thay
// bằng IndexedDB thông qua package:browser_cache nếu cần bền vững.
// =====================================================================

import 'file_cache_store_base.dart';

/// Factory dùng chung bởi conditional import (nền tảng Web).
FileCacheStore createPlatformFileCacheStore(String rootPath) {
  return MemoryFileCacheStore();
}