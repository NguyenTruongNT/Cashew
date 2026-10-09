// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: KHO ĐỆM LOCAL FILE (NỀN TẢNG IO)]
// File: lib/struct/sync/file_cache_store_io.dart
// Mô tả: Bản cài đặt FileCacheStore dùng ổ đĩa thật (dart:io) cho
// Desktop (Windows/Linux/macOS) và thiết bị di động. File này chỉ được
// biên dịch khi nền tảng hỗ trợ dart:io (nhờ conditional import ở
// file_cache_store.dart), nên không làm vỡ bản build Web.
// =====================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'file_cache_store_base.dart';

/// Lưu tệp cục bộ trong thư mục được chỉ định, mỗi tài liệu 1 tệp
/// theo tên `{documentId}.bin`.
class IoFileCacheStore extends FileCacheStore {
  final Directory root;

  IoFileCacheStore(this.root) {
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }
  }

  File _fileOf(String documentId) => File(p.join(root.path, '$documentId.bin'));

  @override
  Future<void> write(String documentId, List<int> bytes) async {
    final f = _fileOf(documentId);
    await f.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> read(String documentId) async {
    final f = _fileOf(documentId);
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  }

  @override
  Future<bool> exists(String documentId) async => _fileOf(documentId).exists();

  @override
  Future<int> size(String documentId) async {
    final f = _fileOf(documentId);
    if (!await f.exists()) return 0;
    return await f.length();
  }

  @override
  Future<void> delete(String documentId) async {
    final f = _fileOf(documentId);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<List<String>> listDocumentIds() async {
    if (!await root.exists()) return const [];
    return root
        .listSync()
        .whereType<File>()
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }
}

/// Factory dùng chung bởi conditional import (nền tảng có dart:io).
FileCacheStore createPlatformFileCacheStore(String rootPath) {
  return IoFileCacheStore(Directory(rootPath));
}