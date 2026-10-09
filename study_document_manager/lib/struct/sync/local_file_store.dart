// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG LƯU TRỮ CỤC BỘ: LOCAL FILE STORE]
// File: lib/struct/sync/local_file_store.dart
// Mô tả: Trừu tượng hóa nơi lưu tệp tài liệu cục bộ (Offline cache).
// Cho phép thay thế bằng bộ nhớ (test) hoặc hệ thống tệp thật (native).
// =====================================================================

/// Giao diện lưu trữ tệp cục bộ.
abstract class LocalFileStore {
  /// Lưu [bytes] với tên gợi ý [fileName]; trả về "khóa/đường dẫn" nội bộ.
  Future<String> save(String fileName, List<int> bytes);

  /// Đọc nội dung tệp theo khóa; trả về null nếu không tồn tại.
  Future<List<int>?> read(String path);

  /// Kiểm tra tệp có tồn tại cục bộ hay không.
  Future<bool> exists(String path);

  /// Xóa tệp cục bộ.
  Future<void> delete(String path);
}

/// Bản triển khai lưu trong bộ nhớ — dùng cho unit test và fallback Web.
class InMemoryFileStore implements LocalFileStore {
  final Map<String, List<int>> _files = {};
  int _counter = 0;

  @override
  Future<String> save(String fileName, List<int> bytes) async {
    final key = 'mem://${_counter++}/$fileName';
    _files[key] = List<int>.from(bytes);
    return key;
  }

  @override
  Future<List<int>?> read(String path) async {
    final data = _files[path];
    return data == null ? null : List<int>.from(data);
  }

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
  }

  /// Số tệp đang lưu (hữu ích cho kiểm thử).
  int get fileCount => _files.length;
}
