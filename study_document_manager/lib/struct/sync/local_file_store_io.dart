// =====================================================================
// [LOCAL FILE STORE - BẢN NATIVE (Android/iOS/Desktop)]
// File: lib/struct/sync/local_file_store_io.dart
// Mô tả: Lưu tệp cục bộ thật trên hệ thống tệp thiết bị.
// =====================================================================

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'local_file_store.dart';

/// Bản triển khai dùng hệ thống tệp thật của thiết bị.
class IoLocalFileStore implements LocalFileStore {
  IoLocalFileStore(this.baseDirectory);

  /// Thư mục gốc chứa cache tệp tài liệu.
  final Directory baseDirectory;

  @override
  Future<String> save(String fileName, List<int> bytes) async {
    if (!await baseDirectory.exists()) {
      await baseDirectory.create(recursive: true);
    }
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = File(
      p.join(baseDirectory.path, '${const Uuid().v4()}_$safeName'),
    );
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  @override
  Future<List<int>?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Tạo LocalFileStore mặc định cho nền tảng native.
Future<LocalFileStore> createDefaultLocalFileStore() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final cacheDir = Directory(p.join(docsDir.path, 'document_cache'));
  return IoLocalFileStore(cacheDir);
}
