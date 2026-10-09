// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: BỘ MÁY ĐỒNG BỘ HAI CHIỀU]
// File: lib/struct/sync/sync_engine.dart
// Mô tả: Thực thi cơ chế Offline-First:
//   1. Thao tác cục bộ được ghi ngay vào SQLite + đưa vào hàng đợi outbox.
//   2. Khi có mạng, PUSH outbox lên Cloud (kèm kiểm tra checksum MD5/SHA-256).
//   3. PULL thay đổi từ Cloud về (so khớp `version`, xử lý xung đột).
//   4. Cập nhật bảng `delete_logs` khi đồng bộ xóa.
//   5. Tự động kích hoạt lại khi mạng phục hồi nhờ NetworkMonitor.
// =====================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../checksum_utils.dart';
import '../models/document_models.dart';
import '../models/sync_models.dart';
import 'local_file_store.dart';
import 'network_monitor.dart';
import 'remote_sync_service.dart';

/// Pha xử lý của một chu kỳ đồng bộ.
enum SyncPhase { idle, syncing, success, error }

/// Kết quả chi tiết của một lần đồng bộ.
class SyncResult {
  final bool success;
  final int pushedDocuments;
  final int pulledDocuments;
  final int deletedDocuments;
  final int uploadedFiles;
  final int conflicts;
  final int failed;
  final Duration duration;
  final List<String> errors;

  const SyncResult({
    required this.success,
    required this.duration,
    this.pushedDocuments = 0,
    this.pulledDocuments = 0,
    this.deletedDocuments = 0,
    this.uploadedFiles = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.errors = const [],
  });

  String get summary {
    if (failed > 0) {
      return 'Đồng bộ lỗi ($failed mục). Đã đẩy $pushedDocuments, kéo $pulledDocuments.';
    }
    if (pushedDocuments == 0 &&
        pulledDocuments == 0 &&
        deletedDocuments == 0 &&
        conflicts == 0) {
      return 'Mọi dữ liệu đã được đồng bộ.';
    }
    return 'Đã đẩy $pushedDocuments, kéo $pulledDocuments, xóa $deletedDocuments'
        '${conflicts > 0 ? ', $conflicts xung đột' : ''}.';
  }
}

/// Ảnh chụp trạng thái đồng bộ phục vụ UI.
class SyncSnapshot {
  final SyncPhase phase;
  final int pendingCount;
  final bool isOnline;
  final SyncResult? lastResult;
  final DateTime? lastSyncAt;

  const SyncSnapshot({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.isOnline = true,
    this.lastResult,
    this.lastSyncAt,
  });

  SyncSnapshot copyWith({
    SyncPhase? phase,
    int? pendingCount,
    bool? isOnline,
    SyncResult? lastResult,
    DateTime? lastSyncAt,
  }) {
    return SyncSnapshot(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      isOnline: isOnline ?? this.isOnline,
      lastResult: lastResult ?? this.lastResult,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

/// Kết quả áp dụng một thay đổi từ Cloud xuống cục bộ.
enum _RemoteApply { inserted, updated, deleted, conflicted, ignored }

/// Bộ máy đồng bộ hai chiều Offline-First.
class SyncEngine {
  SyncEngine({
    required this.database,
    required this.remote,
    required this.fileStore,
    required this.ownerId,
    this.downloadRemoteFiles = true,
    this.maxRetries = 5,
  });

  final AppDatabase database;
  final RemoteSyncService remote;
  final LocalFileStore fileStore;
  final String ownerId;
  final bool downloadRemoteFiles;
  final int maxRetries;

  final ValueNotifier<SyncSnapshot> snapshot =
      ValueNotifier<SyncSnapshot>(const SyncSnapshot());

  NetworkMonitor? _networkMonitor;
  StreamSubscription<bool>? _networkSubscription;
  bool _syncing = false;

  /// Gắn NetworkMonitor để tự động đồng bộ khi mạng phục hồi.
  void bindNetworkMonitor(NetworkMonitor monitor) {
    _networkMonitor?.dispose();
    _networkMonitor = monitor;
    _networkSubscription?.cancel();
    _networkSubscription = monitor.onStatusChange.listen((online) {
      snapshot.value = snapshot.value.copyWith(isOnline: online);
      if (online) {
        unawaited(syncNow());
      }
    });
    snapshot.value = snapshot.value.copyWith(isOnline: monitor.isOnline);
    monitor.start();
  }

  /// Khởi tạo trạng thái (đếm số mục đang chờ).
  Future<void> initialize() async {
    final pending = await database.getPendingSyncCount();
    snapshot.value = snapshot.value.copyWith(
      pendingCount: pending,
      lastSyncAt: await database.getLastSyncAt(),
    );
  }

  /// Thực hiện một chu kỳ đồng bộ hai chiều.
  Future<SyncResult> syncNow() async {
    if (_syncing) {
      return snapshot.value.lastResult ??
          const SyncResult(success: false, duration: Duration.zero);
    }
    _syncing = true;
    snapshot.value = snapshot.value.copyWith(phase: SyncPhase.syncing);

    final stopwatch = Stopwatch()..start();
    var pushed = 0;
    var pulled = 0;
    var deleted = 0;
    var uploaded = 0;
    var conflicts = 0;
    var failed = 0;
    final errors = <String>[];
    var networkDown = false;

    try {
      if (!await remote.ping()) {
        throw const RemoteNetworkException();
      }

      // ---------------- PUSH: đẩy hàng đợi cục bộ lên Cloud ----------------
      final entries = await database.getOutboxEntries();
      for (final entry in entries) {
        try {
          if (entry.operation == SyncOperation.delete) {
            await _pushDelete(entry);
            deleted++;
          } else {
            final uploadedNow = await _pushUpsert(entry);
            if (uploadedNow) uploaded++;
            pushed++;
          }
          await database.removeOutboxEntry(entry.id);
        } on RemoteConflictException catch (e) {
          conflicts++;
          await _handleConflict(entry, e.remote);
          await database.removeOutboxEntry(entry.id);
        } catch (e) {
          failed++;
          errors.add('Đẩy ${entry.entityId}: $e');
          await database.incrementOutboxRetry(entry.id, e.toString());
          if (e is RemoteNetworkException) {
            networkDown = true;
            break;
          }
        }
      }

      // ---------------- PULL: kéo thay đổi mới từ Cloud về ----------------
      if (!networkDown) {
        final lastSync = await database.getLastSyncAt();
        final changes = await remote.pullChanges(
          ownerId: ownerId,
          since: lastSync,
        );
        for (final remoteDoc in changes) {
          try {
            final applied = await _applyRemote(remoteDoc);
            switch (applied) {
              case _RemoteApply.inserted:
                pulled++;
                break;
              case _RemoteApply.updated:
                pulled++;
                break;
              case _RemoteApply.deleted:
                deleted++;
                break;
              case _RemoteApply.conflicted:
                conflicts++;
                break;
              case _RemoteApply.ignored:
                break;
            }
          } catch (e) {
            failed++;
            errors.add('Kéo ${remoteDoc.id}: $e');
          }
        }

        final serverNow = await remote.serverTime();
        await database.setLastSyncAt(serverNow);
        await database.notifyDocumentsChanged();
      }
    } on RemoteNetworkException catch (e) {
      failed++;
      networkDown = true;
      errors.add(e.toString());
    } catch (e) {
      failed++;
      errors.add(e.toString());
    } finally {
      stopwatch.stop();
      _syncing = false;
    }

    final pending = await database.getPendingSyncCount();
    final result = SyncResult(
      success: failed == 0 && !networkDown,
      duration: stopwatch.elapsed,
      pushedDocuments: pushed,
      pulledDocuments: pulled,
      deletedDocuments: deleted,
      uploadedFiles: uploaded,
      conflicts: conflicts,
      failed: failed,
      errors: errors,
    );
    snapshot.value = snapshot.value.copyWith(
      phase: result.success ? SyncPhase.success : SyncPhase.error,
      pendingCount: pending,
      lastResult: result,
      lastSyncAt: await database.getLastSyncAt(),
    );
    return result;
  }

  /// Đẩy một tài liệu (upsert) lên Cloud. Trả về true nếu có upload tệp mới.
  Future<bool> _pushUpsert(SyncOutboxEntry entry) async {
    final doc = await database.getDocumentById(entry.entityId);
    if (doc == null) return false;

    final algorithm = ChecksumAlgorithm.fromString(doc.checksumAlgorithm);
    var storagePath = doc.storagePath;
    var checksum = doc.checksum;
    var uploadedNow = false;

    // Nếu tệp đã được upload trực tiếp (Firebase) trước đó thì bỏ qua bước
    // upload lại, chỉ đồng bộ metadata + checksum.
    final fileAlreadyUploaded = entry.payload?['file_uploaded'] == true;

    // Nếu có tệp cục bộ (Offline cache) thì upload + xác minh checksum.
    if (doc.localPath != null && !fileAlreadyUploaded) {
      final bytes = await fileStore.read(doc.localPath!);
      if (bytes != null) {
        final computed = ChecksumUtils.compute(bytes, algorithm: algorithm);
        if (checksum != null &&
            checksum.isNotEmpty &&
            !ChecksumUtils.verify(bytes, checksum, algorithm: algorithm)) {
          throw StateError(
            'Checksum cục bộ không khớp (mong đợi $checksum). Tệp có thể hỏng.',
          );
        }
        storagePath = await remote.uploadFile(
          ownerId: ownerId,
          documentId: doc.id,
          fileName: p.basename(doc.localPath!),
          bytes: bytes,
        );
        checksum = computed;
        uploadedNow = true;
      }
    }

    final data = doc.toMap();
    data['storage_path'] = storagePath;
    data['checksum'] = checksum;
    data['checksum_algo'] = algorithm.nameString;
    data['sync_status'] = SyncStatus.synced.nameString;
    data['version'] = doc.version;
    data['updated_date'] = doc.updatedDate.millisecondsSinceEpoch;

    final canonical = await remote.pushDocument(
      RemoteDocument(
        id: doc.id,
        ownerId: ownerId,
        version: doc.version,
        updatedAt: doc.updatedDate,
        data: data,
        checksum: checksum,
        checksumAlgorithm: algorithm.nameString,
        storagePath: storagePath,
      ),
    );

    await database.markDocumentSyncStatus(
      doc.id,
      syncStatus: SyncStatus.synced,
      version: canonical.version,
      remoteUpdatedAt: canonical.updatedAt,
      lastSyncedAt: DateTime.now(),
      checksum: checksum,
      checksumAlgorithm: algorithm.nameString,
      storagePath: canonical.storagePath ?? storagePath,
    );
    return uploadedNow;
  }

  /// Đẩy thao tác xóa lên Cloud và cập nhật bảng delete_logs.
  Future<void> _pushDelete(SyncOutboxEntry entry) async {
    final payload = entry.payload ?? const <String, dynamic>{};
    final storagePath = payload['storage_path'] as String?;
    final deleteLogId = payload['delete_log_id'] as String?;

    if (storagePath != null && storagePath.isNotEmpty) {
      await remote.deleteFile(storagePath: storagePath);
    }
    await remote.deleteRemoteDocument(
      ownerId: ownerId,
      documentId: entry.entityId,
      storagePath: storagePath,
    );

    if (deleteLogId != null) {
      await database.updateDeleteLogStatus(
        deleteLogId,
        DeleteLogStatus.synced,
        remoteUpdatedAt: DateTime.now(),
      );
    }
  }

  /// Xử lý xung đột phiên bản: Last-Write-Wins có kiểm soát.
  Future<void> _handleConflict(
    SyncOutboxEntry entry,
    RemoteDocument remoteDoc,
  ) async {
    final local = await database.getDocumentById(entry.entityId);
    if (local == null) return;

    if (local.updatedDate.isAfter(remoteDoc.updatedAt)) {
      // Cục bộ mới hơn -> đẩy lại với version cao hơn remote (ưu tiên cục bộ).
      await database.updateDocument(
        local.copyWith(
          version: remoteDoc.version + 1,
          syncStatus: SyncStatus.pendingUpload,
          updatedDate: local.updatedDate,
        ),
      );
      await database.enqueueOutbox(
        entityId: local.id,
        operation: SyncOperation.upsert,
      );
    } else {
      // Cloud mới hơn -> chấp nhận bản Cloud.
      await database.updateDocument(remoteDoc.toLocalDocument());
    }
    await database.notifyDocumentsChanged();
  }

  /// Áp dụng một thay đổi từ Cloud xuống cục bộ.
  Future<_RemoteApply> _applyRemote(RemoteDocument remoteDoc) async {
    final local = await database.getDocumentById(remoteDoc.id);

    // ---- Trường hợp Cloud báo đã xóa ----
    if (remoteDoc.isDeleted) {
      if (local == null) return _RemoteApply.ignored;
      await _logRemoteDeletion(remoteDoc);
      if (local.localPath != null) {
        await fileStore.delete(local.localPath!);
      }
      await database.hardDeleteDocument(remoteDoc.id);
      return _RemoteApply.deleted;
    }

    // ---- Trường hợp cục bộ chưa có -> thêm mới ----
    if (local == null) {
      var localDoc = remoteDoc.toLocalDocument();
      if (downloadRemoteFiles && remoteDoc.storagePath != null) {
        final bytes = await remote.downloadFile(
          storagePath: remoteDoc.storagePath!,
        );
        if (bytes != null) {
          final valid = remoteDoc.checksum == null ||
              remoteDoc.checksum!.isEmpty ||
              ChecksumUtils.verify(bytes, remoteDoc.checksum!);
          final path = await fileStore.save(
            p.basename(remoteDoc.storagePath!),
            bytes,
          );
          localDoc = localDoc.copyWith(
            localPath: path,
            syncStatus: valid ? SyncStatus.synced : SyncStatus.conflict,
            updatedDate: localDoc.updatedDate,
          );
        }
      }
      await database.insertDocument(localDoc);
      return _RemoteApply.inserted;
    }

    // ---- Cục bộ đã có -> so sánh version ----
    if (remoteDoc.version <= local.version) {
      return _RemoteApply.ignored;
    }

    final localDirty = local.syncStatus == SyncStatus.pendingUpload ||
        local.syncStatus == SyncStatus.pendingDelete ||
        local.syncStatus == SyncStatus.conflict;

    if (localDirty && local.updatedDate.isAfter(remoteDoc.updatedAt)) {
      // Cục bộ mới hơn -> giữ cục bộ, đánh dấu xung đột để đẩy ở chu kỳ sau.
      await database.updateDocument(
        local.copyWith(
          syncStatus: SyncStatus.conflict,
          updatedDate: local.updatedDate,
        ),
      );
      return _RemoteApply.conflicted;
    }

    // Cloud mới hơn -> ghi đè cục bộ (Last-Write-Wins).
    await database.updateDocument(remoteDoc.toLocalDocument());
    return _RemoteApply.updated;
  }

  /// Ghi nhận một thao tác xóa đến từ Cloud vào bảng delete_logs.
  Future<void> _logRemoteDeletion(RemoteDocument remoteDoc) async {
    final existing = await database.getDeleteLogs();
    final alreadyLogged =
        existing.any((log) => log.documentId == remoteDoc.id);
    if (alreadyLogged) return;
    await database.insertDeleteLog(
      DeleteLogModel(
        id: const Uuid().v4(),
        documentId: remoteDoc.id,
        ownerId: remoteDoc.ownerId,
        storagePath: remoteDoc.storagePath,
        checksum: remoteDoc.checksum,
        deletedAt: remoteDoc.updatedAt,
        source: 'remote',
        syncStatus: DeleteLogStatus.synced,
        remoteUpdatedAt: remoteDoc.updatedAt,
      ),
    );
  }

  Future<void> dispose() async {
    await _networkSubscription?.cancel();
    _networkMonitor?.dispose();
    snapshot.dispose();
  }
}
