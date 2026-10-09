// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: GIAO DIỆN CLOUD BACKEND]
// File: lib/struct/sync/sync_backend.dart
// Mô tả:
//  - SyncBackend   : hợp đồng truy cập Cloud (metadata + byte tệp).
//  - InMemorySyncBackend : bản giả lập chạy trong bộ nhớ, cho phép mô phỏng
//    độ trễ mạng, băng thông và lỗi thoáng qua — phục vụ kiểm thử khi mạng yếu.
// Bản cài đặt thật với Firebase (Firestore + Storage + Auth) nằm ở
// firebase_sync_backend.dart triển khai cùng hợp đồng này.
// =====================================================================

import 'dart:async';

import 'sync_models.dart';

/// Hợp đồng giữa ứng dụng và dịch vụ Cloud (Firestore + Firebase Storage).
abstract class SyncBackend {
  /// Kéo danh sách tài liệu thay đổi kể từ mốc [since] (null = tất cả).
  Future<List<RemoteDocument>> pullDocuments({DateTime? since});

  /// Đẩy/ghi mới một tài liệu lên Cloud, trả về phiên bản đã lưu phía server.
  Future<RemoteDocument> upsertDocument(RemoteDocument document);

  /// Thông báo xóa một tài liệu + thời điểm xóa (tombstone) lên Cloud.
  Future<void> deleteDocument(
    String documentId,
    DateTime deletedAt, {
    String? checksum,
  });

  /// Kéo danh sách tombstone xóa kể từ mốc [since].
  Future<List<DeleteLogEntry>> pullDeletes({DateTime? since});

  /// Tải tệp lên Cloud. [checksum] xác thực nội dung tệp.
  Future<void> uploadFile(String documentId, String checksum, List<int> bytes);

  /// Tải tệp xuống; trả về null nếu tệp chưa có hoặc checksum không khớp.
  Future<List<int>?> downloadFile(String documentId, String checksum);

  /// Xóa tệp trên Cloud.
  Future<void> deleteFile(String documentId);
}

/// Bản giả lập Cloud chạy trong bộ nhớ.
///
/// Hỗ trợ mô phỏng:
///  - [online]: tắt để mô phỏng mất mạng (ném [SyncNetworkException]).
///  - [latency] + [bytesPerSecond]: mô phỏng mạng yếu (độ trễ + băng thông).
///  - [failNext]: làm hỏng N lần gọi liên tiếp để kiểm thử cơ chế retry.
class InMemorySyncBackend implements SyncBackend {
  final Map<String, RemoteDocument> _documents = {};
  final Map<String, DeleteLogEntry> _deleteLogs = {};
  final Map<String, List<int>> _files = {};
  final Map<String, String> _fileChecksums = {};

  int _remoteVersionCounter = 0;

  /// Cloud đang online.
  bool online = true;

  /// Độ trễ mạng cố định cho mỗi lần gọi (mặc định 0).
  Duration latency = Duration.zero;

  /// Băng thông mô phỏng (byte/giây); 0 = truyền tức thì.
  int bytesPerSecond = 0;

  /// Số lần gọi liên tiếp sẽ bị làm hỏng (lỗi thoáng qua).
  int _failuresRemaining = 0;

  /// Thống kê lượng byte truyền tải (phục vụ đo hiệu năng mạng yếu).
  int bytesUploaded = 0;
  int bytesDownloaded = 0;

  /// Tổng số lần gọi thực sự được thực hiện (không tính lần bị chặn trước).
  int totalCalls = 0;

  InMemorySyncBackend();

  /// Làm hỏng [times] lần gọi tiếp theo (mô phỏng mạng chập chờn).
  void failNext(int times) {
    _failuresRemaining = _failuresRemaining + times;
  }

  bool get hasFailures => _failuresRemaining > 0;

  /// Số tài liệu đang giữ trên "Cloud".
  int get cloudDocumentCount => _documents.length;

  /// Kiểm tra trạng thái mạng & lỗi thoáng qua trước mỗi thao tác.
  void _checkOnline() {
    if (!online) {
      throw SyncNetworkException('Mất kết nối mạng (offline)');
    }
    if (_failuresRemaining > 0) {
      _failuresRemaining--;
      throw SyncNetworkException('Mạng chập chờn: lỗi thoáng qua còn $_failuresRemaining lần');
    }
  }

  /// Mô phỏng thời gian truyền tải theo băng thông.
  Future<void> _simulateTransfer(int bytes) async {
    _checkOnline();
    var wait = latency;
    if (bytesPerSecond > 0 && bytes > 0) {
      final transferMs = (bytes / bytesPerSecond * 1000).round();
      wait += Duration(milliseconds: transferMs);
    }
    if (wait > Duration.zero) {
      await Future.delayed(wait);
    }
  }

  @override
  Future<List<RemoteDocument>> pullDocuments({DateTime? since}) async {
    _checkOnline();
    totalCalls++;
    await _simulateTransfer(0);

    final list = _documents.values
        .where((d) => !d.deleted && (since == null || d.updatedDate.isAfter(since)))
        .toList()
      ..sort((a, b) => a.updatedDate.compareTo(b.updatedDate));
    return list;
  }

  @override
  Future<RemoteDocument> upsertDocument(RemoteDocument document) async {
    _checkOnline();
    totalCalls++;
    // Mô phỏng "độ trễ" ghi dữ liệu nhỏ.
    await _simulateTransfer(document.toMap().length);

    _remoteVersionCounter++;
    final stored = document.copyWith(remoteVersion: _remoteVersionCounter);
    _documents[document.id] = stored;
    return stored;
  }

  @override
  Future<void> deleteDocument(
    String documentId,
    DateTime deletedAt, {
    String? checksum,
  }) async {
    _checkOnline();
    totalCalls++;

    final log = DeleteLogEntry(
      id: 'remote_${documentId}_${deletedAt.millisecondsSinceEpoch}',
      documentId: documentId,
      deletedAt: deletedAt,
      deviceId: 'cloud',
      checksum: checksum,
      synced: true,
    );
    _deleteLogs[log.id] = log;
    _documents.remove(documentId);
    _files.remove(documentId);
    _fileChecksums.remove(documentId);
  }

  @override
  Future<List<DeleteLogEntry>> pullDeletes({DateTime? since}) async {
    _checkOnline();
    totalCalls++;
    await _simulateTransfer(0);

    return _deleteLogs.values
        .where((e) => since == null || e.deletedAt.isAfter(since))
        .toList()
      ..sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
  }

  @override
  Future<void> uploadFile(String documentId, String checksum, List<int> bytes) async {
    _checkOnline();
    totalCalls++;
    await _simulateTransfer(bytes.length);

    _files[documentId] = List<int>.from(bytes);
    _fileChecksums[documentId] = checksum;
    bytesUploaded += bytes.length;
  }

  @override
  Future<List<int>?> downloadFile(String documentId, String checksum) async {
    _checkOnline();
    totalCalls++;
    await _simulateTransfer(_files[documentId]?.length ?? 0);

    final bytes = _files[documentId];
    final storedChecksum = _fileChecksums[documentId];
    if (bytes == null) return null;
    // Kiểm tra tính toàn vẹn: checksum không khớp => coi như tệp hỏng.
    if (storedChecksum != null && storedChecksum != checksum) return null;
    bytesDownloaded += bytes.length;
    return List<int>.from(bytes);
  }

  @override
  Future<void> deleteFile(String documentId) async {
    _checkOnline();
    totalCalls++;
    _files.remove(documentId);
    _fileChecksums.remove(documentId);
  }

  /// Tiện ích test: ghi trực tiếp một tài liệu phía "Cloud" (mô phỏng thiết bị khác).
  void seedRemoteDocument(RemoteDocument doc) {
    _remoteVersionCounter = doc.remoteVersion > _remoteVersionCounter
        ? doc.remoteVersion
        : _remoteVersionCounter;
    _documents[doc.id] = doc;
  }

  /// Tiện ích test: kiểm tra tài liệu hiện có trên "Cloud".
  RemoteDocument? remoteDocument(String id) => _documents[id];
}

/// Tiện ích: bọc một SyncBackend để đo độ trễ/byte (optional wrapper).
class TimingSyncBackend implements SyncBackend {
  final SyncBackend inner;
  int latencyMs = 0;
  int totalBytes = 0;

  TimingSyncBackend(this.inner);

  @override
  Future<void> deleteDocument(String documentId, DateTime deletedAt, {String? checksum}) async {
    await inner.deleteDocument(documentId, deletedAt, checksum: checksum);
  }

  @override
  Future<void> deleteFile(String documentId) => inner.deleteFile(documentId);

  @override
  Future<List<int>?> downloadFile(String documentId, String checksum) async {
    final result = await inner.downloadFile(documentId, checksum);
    totalBytes += result?.length ?? 0;
    return result;
  }

  @override
  Future<List<DeleteLogEntry>> pullDeletes({DateTime? since}) => inner.pullDeletes(since: since);

  @override
  Future<List<RemoteDocument>> pullDocuments({DateTime? since}) => inner.pullDocuments(since: since);

  @override
  Future<void> uploadFile(String documentId, String checksum, List<int> bytes) async {
    await inner.uploadFile(documentId, checksum, bytes);
    totalBytes += bytes.length;
  }

  @override
  Future<RemoteDocument> upsertDocument(RemoteDocument document) => inner.upsertDocument(document);
}