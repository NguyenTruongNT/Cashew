// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: DỊCH VỤ ĐỒNG BỘ HAI CHIỀU]
// File: lib/struct/sync/offline_sync_service.dart
// Mô tả: Điều phối toàn bộ cơ chế Offline-First:
//  1. Local Cache kết hợp Cloud (đọc/ghi tệp cục bộ khi Offline).
//  2. Tự động đồng bộ hai chiều khi mạng trở lại.
//  3. Kiểm tra tính toàn vẹn tệp bằng Checksum (MD5/SHA-256).
//  4. Cập nhật bảng delete_logs (tombstone) khi xóa offline.
//  5. Chính sách xung đột Last-Write-Wins theo updated_date.
//  6. Retry + timeout khi mạng yếu, kèm số liệu hiệu năng truyền tải.
// =====================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../database/app_database.dart';
import '../models/document_models.dart';
import 'checksum_util.dart';
import 'connectivity_monitor.dart';
import 'file_cache_store.dart';
import 'sync_backend.dart';
import 'sync_models.dart';
import 'sync_status.dart';

/// Dịch vụ đồng bộ Offline-First.
class OfflineSyncService {
  final AppDatabase db;
  final SyncBackend backend;
  final ConnectivityMonitor connectivity;
  final FileCacheStore fileCache;
  final String deviceId;

  /// Số lần thử lại tối đa khi gặp lỗi mạng thoáng qua.
  final int maxRetries;

  /// Thời gian chờ giữa các lần thử lại.
  final Duration retryDelay;

  /// Thời gian tối đa chờ một thao tác Cloud (phòng mạng kéo dài).
  final Duration operationTimeout;

  /// Trạng thái đồng bộ hiện tại (có thể lắng nghe để hiển thị badge).
  final ValueNotifier<SyncState> state = ValueNotifier<SyncState>(SyncState.idle);

  StreamSubscription<bool>? _connectivitySub;
  bool _syncing = false;
  bool _disposed = false;
  int _attempts = 0;

  OfflineSyncService({
    required this.db,
    required this.backend,
    required this.connectivity,
    required this.fileCache,
    this.deviceId = 'local-device',
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 300),
    this.operationTimeout = const Duration(seconds: 30),
  }) {
    db.deviceId = deviceId;
  }

  /// Số bản ghi hiện đang chờ đồng bộ (tài liệu + tombstone xóa).
  Future<int> pendingCount() => db.countPendingSyncChanges();

  /// Bắt đầu lắng nghe mạng: khi mạng trở lại (offline -> online) thì
  /// tự động gọi [syncNow]. Nếu đang online ngay từ đầu, đồng bộ 1 lần.
  Future<void> startAutoSync() async {
    await connectivity.start();
    _connectivitySub = connectivity.onStatusChange.listen((online) async {
      await _refreshState();
      if (online) {
        await syncNow();
      }
    });
    await _refreshState();
    if (connectivity.isOnline) {
      await syncNow();
    }
  }

  Future<void> _refreshState() async {
    if (_disposed) return;
    final pending = await db.countPendingSyncChanges();
    state.value = state.value.copyWith(
      online: connectivity.isOnline,
      pendingCount: pending,
    );
  }

  /// Thực hiện một phiên đồng bộ hai chiều. Trả về báo cáo chi tiết.
  ///
  /// Thứ tự đúng đắn để bảo toàn Last-Write-Wins:
  ///  1. PULL metadata + tombstone từ Cloud, MERGE theo updated_date.
  ///  2. PUSH các tài liệu / tombstone còn chờ (bản cục bộ thắng).
  ///  3. Đồng bộ byte tệp cho từng tài liệu theo kết quả merge.
  Future<SyncReport> syncNow() async {
    await _refreshState();

    if (!connectivity.isOnline) {
      if (!_disposed) {
        state.value = state.value.copyWith(
          isSyncing: false,
          lastError: 'Đang offline - thay đổi được lưu vào Local Cache',
        );
      }
      return SyncReport.offline();
    }

    if (_syncing) {
      return SyncReport(
        success: false,
        error: 'Đã có phiên đồng bộ khác đang chạy',
      );
    }
    _syncing = true;
    _attempts = 0;
    if (!_disposed) {
      state.value = state.value.copyWith(isSyncing: true, clearError: true);
    }

    final stopwatch = Stopwatch()..start();
    var pushed = 0, pulled = 0, pushedDeletes = 0, appliedDeletes = 0;
    var uploadedFiles = 0, downloadedFiles = 0, conflicts = 0;
    var bytesUp = 0, bytesDown = 0;

    try {
      // Mốc thời gian gần nhất đã xử lý (để lần sau kéo phần mới hơn).
      DateTime? latest = await db.getLastSyncAt();

      // ==============================================================
      // BƯỚC 1a: KÉO (PULL) TÀI LIỆU THAY ĐỔI TỪ CLOUD + MERGE (LWW)
      // ==============================================================
      final remoteDocs = await _retry(() => backend.pullDocuments(since: latest));
      final localWinsDocIds = <String>{};

      for (final remote in remoteDocs) {
        latest = _maxTime(latest, remote.updatedDate);
        final local = await db.getDocumentById(remote.id);

        if (local == null) {
          // Chưa có cục bộ -> tải về.
          await db.applyRemoteDocument(_toLocal(remote), remoteVersion: remote.remoteVersion);
          pulled++;
        } else if (local.isPendingSync) {
          // Xung đột: bản có updated_date mới hơn sẽ thắng (Last-Write-Wins).
          if (remote.updatedDate.isAfter(local.updatedDate)) {
            // Cloud mới hơn -> bỏ thay đổi cục bộ, lấy bản Cloud.
            await db.applyRemoteDocument(_toLocal(remote), remoteVersion: remote.remoteVersion);
            await fileCache.delete(remote.id);
            conflicts++;
          } else {
            // Cục bộ mới hơn -> giữ bản cục bộ, đẩy lên ở Bước 2.
            localWinsDocIds.add(local.id);
          }
        } else if (remote.updatedDate.isAfter(local.updatedDate)) {
          await db.applyRemoteDocument(_toLocal(remote), remoteVersion: remote.remoteVersion);
          pulled++;
        }
      }

      // ==============================================================
      // BƯỚC 1b: KÉO (PULL) TOMBSTONE XÓA TỪ CLOUD + MERGE (LWW)
      // ==============================================================
      final remoteDeletes = await _retry(() => backend.pullDeletes(since: latest));
      for (final remoteDelete in remoteDeletes) {
        latest = _maxTime(latest, remoteDelete.deletedAt);
        final local = await db.getDocumentById(remoteDelete.documentId);
        if (local == null) continue; // đã xóa rồi

        // Xung đột xóa/sửa: chỉnh sửa cục bộ mới hơn lệnh xóa -> giữ (hồi sinh).
        if (local.isPendingSync && local.updatedDate.isAfter(remoteDelete.deletedAt)) {
          localWinsDocIds.add(local.id);
          conflicts++;
          continue;
        }

        await db.applyRemoteDelete(remoteDelete.documentId);
        await fileCache.delete(remoteDelete.documentId);
        appliedDeletes++;
      }

      // ==============================================================
      // BƯỚC 2: ĐẨY (PUSH) CÁC THAY ĐỔI CỤC BỘ CÒN CHỜ LÊN CLOUD
      // ==============================================================
      final pendingDocs = await db.getPendingDocuments();
      for (final doc in pendingDocs) {
        // (a) Tệp đính kèm: upload nếu có trong Local Cache, kèm checksum.
        final localBytes = await fileCache.read(doc.id);
        String? checksum = doc.checksum;
        if (localBytes != null) {
          final computed = ChecksumUtil.sha256Hex(localBytes);
          if (!ChecksumUtil.matches(computed, doc.checksum)) {
            checksum = computed;
            await db.updateDocumentFileMetadata(
              doc.id,
              checksum: computed,
              fileSize: localBytes.length,
              localFilePath: doc.localFilePath ?? 'cache://local/${doc.id}',
            );
          }
          await _retry(() => backend.uploadFile(doc.id, computed, localBytes));
          bytesUp += localBytes.length;
          uploadedFiles++;
        }

        // (b) Metadata tài liệu.
        final remote = await _retry(
          () => backend.upsertDocument(_toRemote(doc, checksum: checksum)),
        );
        await db.markDocumentSynced(
          doc.id,
          remoteVersion: remote.remoteVersion,
          checksum: checksum,
          fileSize: doc.fileSize,
        );
        latest = _maxTime(latest, doc.updatedDate);
        pushed++;
      }

      // ==============================================================
      // BƯỚC 2b: ĐẨY (PUSH) CÁC LỆNH XÓA (TOMBSTONE - delete_logs)
      // ==============================================================
      final pendingDeletes = await db.getPendingDeleteLogs();
      for (final log in pendingDeletes) {
        await _retry(
          () => backend.deleteDocument(log.documentId, log.deletedAt, checksum: log.checksum),
        );
        await db.markDeleteLogSynced(log.id);
        await fileCache.delete(log.documentId);
        pushedDeletes++;
      }

      // ==============================================================
      // BƯỚC 3: ĐỒNG BỘ TỆP XUỐNG LOCAL CACHE (khi Cloud thắng/ mới có)
      // ==============================================================
      for (final remote in remoteDocs) {
        if (remote.checksum == null || remote.checksum!.isEmpty) continue;
        // Bỏ qua nếu bản cục bộ thắng (tệp cục bộ sẽ được dùng).
        if (localWinsDocIds.contains(remote.id)) continue;

        final localFile = await fileCache.read(remote.id);
        final localChecksum =
            localFile == null ? null : ChecksumUtil.sha256Hex(localFile);
        if (localFile == null ||
            !ChecksumUtil.matches(localChecksum, remote.checksum)) {
          final bytes = await _retry(
            () => backend.downloadFile(remote.id, remote.checksum!),
          );
          if (bytes != null) {
            await fileCache.write(remote.id, bytes);
            bytesDown += bytes.length;
            downloadedFiles++;
          }
        }
      }

      stopwatch.stop();
      if (latest != null) {
        await db.setLastSyncAt(latest);
      }

      final report = SyncReport(
        success: true,
        pushedDocuments: pushed,
        pulledDocuments: pulled,
        pushedDeletes: pushedDeletes,
        appliedDeletes: appliedDeletes,
        uploadedFiles: uploadedFiles,
        downloadedFiles: downloadedFiles,
        conflicts: conflicts,
        attempts: _attempts,
        bytesUploaded: bytesUp,
        bytesDownloaded: bytesDown,
        duration: stopwatch.elapsed,
      );

      if (!_disposed) {
        state.value = state.value.copyWith(
          isSyncing: false,
          lastSyncAt: latest ?? DateTime.now(),
          clearError: true,
        );
      }
      await _refreshState();
      return report;
    } catch (e) {
      stopwatch.stop();
      final report = SyncReport.failure(
        e.toString(),
        duration: stopwatch.elapsed,
        attempts: _attempts,
      );
      if (!_disposed) {
        state.value = state.value.copyWith(isSyncing: false, lastError: e.toString());
      }
      await _refreshState();
      return report;
    } finally {
      _syncing = false;
    }
  }

  /// Thực hiện một thao tác Cloud với cơ chế retry + timeout.
  Future<T> _retry<T>(Future<T> Function() operation) async {
    var attempt = 0;
    while (true) {
      attempt++;
      _attempts++;
      try {
        return await operation().timeout(operationTimeout);
      } on TimeoutException {
        if (attempt >= maxRetries) rethrow;
      } on SyncNetworkException {
        if (attempt >= maxRetries) rethrow;
      }
      if (retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  /// Mốc thời gian mới hơn giữa hai giá trị.
  static DateTime? _maxTime(DateTime? a, DateTime b) =>
      (a == null || b.isAfter(a)) ? b : a;

  // ================================================================
  // CHUYỂN ĐỔI DTO (DocumentModel <-> RemoteDocument)
  // ================================================================

  RemoteDocument _toRemote(DocumentModel d, {String? checksum}) {
    return RemoteDocument(
      id: d.id,
      title: d.title,
      subjectId: d.subjectId,
      type: d.type.nameString,
      notes: d.notes,
      fileUrl: d.fileUrl,
      tags: d.tags,
      status: d.status.nameString,
      priority: d.priority.index,
      isFavorite: d.isFavorite,
      deadline: d.deadline,
      createdDate: d.createdDate,
      updatedDate: d.updatedDate,
      checksum: checksum ?? d.checksum,
      fileSize: d.fileSize,
      remoteVersion: d.remoteVersion,
    );
  }

  DocumentModel _toLocal(RemoteDocument r) {
    return DocumentModel(
      id: r.id,
      title: r.title,
      subjectId: r.subjectId,
      type: DocumentTypeExtension.fromString(r.type),
      notes: r.notes,
      fileUrl: r.fileUrl,
      tags: r.tags,
      status: DocumentStatusExtension.fromString(r.status),
      priority: PriorityLevel.values[r.priority.clamp(0, 2)],
      isFavorite: r.isFavorite,
      deadline: r.deadline,
      createdDate: r.createdDate,
      updatedDate: r.updatedDate,
      checksum: r.checksum,
      fileSize: r.fileSize,
      remoteVersion: r.remoteVersion,
      syncStatus: SyncStatus.synced,
    );
  }

  /// Dừng lắng nghe mạng và giải phóng tài nguyên.
  Future<void> dispose() async {
    _disposed = true;
    await _connectivitySub?.cancel();
    await connectivity.dispose();
    state.dispose();
  }
}