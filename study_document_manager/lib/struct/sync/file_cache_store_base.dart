// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: KHO ĐỆM CỤC BỘ (FILE CACHE STORE)]
// File: lib/struct/sync/file_cache_store_base.dart
// Mô tả: Giao diện lưu trữ byte tệp cục bộ (Local Cache) dùng khi Offline,
// cùng bản cài đặt In-Memory an toàn cho mọi nền tảng (Web/Test).
// Bản cài đặt dùng ổ đĩa thật nằm ở file_cache_store_io.dart.
// =====================================================================

import 'dart:typed_data';

/// Hợp đồng lưu trữ nội dung tệp đính kèm của tài liệu trong Local Cache.
///
/// Khóa (key) là `documentId`; phiên bản nội dung được xác thực bằng checksum.
abstract class FileCacheStore {
  /// Ghi (hoặc ghi đè) nội dung tệp cho một tài liệu.
  Future<void> write(String documentId, List<int> bytes);

  /// Đọc nội dung tệp; trả về null nếu chưa có trong cache.
  Future<Uint8List?> read(String documentId);

  /// Kiểm tra tệp đã có trong cache hay chưa.
  Future<bool> exists(String documentId);

  /// Kích thước tệp (byte), 0 nếu chưa có.
  Future<int> size(String documentId);

  /// Xóa tệp khỏi cache.
  Future<void> delete(String documentId);

  /// Liệt kê toàn bộ documentId đang có tệp trong cache.
  Future<List<String>> listDocumentIds();
}

/// Bản cài đặt In-Memory: dùng cho Unit Test, Web fallback hoặc khi chưa cấu hình.
class MemoryFileCacheStore implements FileCacheStore {
  final Map<String, Uint8List> _store = {};

  @override
  Future<void> write(String documentId, List<int> bytes) async {
    _store[documentId] = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> read(String documentId) async {
    final data = _store[documentId];
    return data == null ? null : Uint8List.fromList(data);
  }

  @override
  Future<bool> exists(String documentId) async => _store.containsKey(documentId);

  @override
  Future<int> size(String documentId) async => _store[documentId]?.length ?? 0;

  @override
  Future<void> delete(String documentId) async {
    _store.remove(documentId);
  }

  @override
  Future<List<String>> listDocumentIds() async => _store.keys.toList();
}
