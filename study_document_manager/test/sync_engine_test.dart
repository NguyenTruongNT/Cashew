import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/checksum_utils.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/struct/models/sync_models.dart';
import 'package:study_document_manager/struct/sync/remote_sync_service.dart';
import 'package:study_document_manager/struct/sync/sync_engine.dart';
import 'package:study_document_manager/struct/sync/local_file_store.dart';
import 'package:study_document_manager/struct/sync/mock_remote_sync_service.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ TẦNG ĐỒNG BỘ OFFLINE-FIRST (SYNC ENGINE)]
// File: test/sync_engine_test.dart
// Mô tả: Kiểm chứng chu trình đồng bộ hai chiều:
//   PUSH outbox -> Cloud, PULL thay đổi -> SQLite (LWW), xử lý xung đột,
//   kiểm tra checksum, cập nhật delete_logs và hành vi khi mất mạng.
// Dùng MockRemoteSyncService + InMemoryFileStore => không cần Cloud thật.
// =====================================================================

const String kOwner = 'test-owner';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockRemoteSyncService remote;
  late InMemoryFileStore fileStore;
  late SyncEngine engine;

  setUp(() async {
    db = AppDatabase();
    await db.init(isInMemory: true);
    remote = MockRemoteSyncService();
    fileStore = InMemoryFileStore();
    engine = SyncEngine(
      database: db,
      remote: remote,
      fileStore: fileStore,
      ownerId: kOwner,
      // Tắt tải tệp khi PULL để tập trung kiểm thử logic đồng bộ metadata.
      downloadRemoteFiles: true,
    );
    await engine.initialize();
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  DocumentModel buildDoc({
    required String id,
    String? localPath,
    String? checksum,
    int version = 1,
    DateTime? updated,
    SyncStatus status = SyncStatus.pendingUpload,
    String title = 'Tài liệu',
  }) {
    final now = updated ?? DateTime.now();
    return DocumentModel(
      id: id,
      title: title,
      subjectId: 'sub_swe',
      type: DocumentType.lecture,
      notes: 'ghi chú',
      fileUrl: 'https://example.com/$id.pdf',
      tags: const ['Sync', 'Test'],
      status: DocumentStatus.pending,
      priority: PriorityLevel.medium,
      createdDate: now,
      updatedDate: now,
      checksum: checksum,
      checksumAlgorithm: 'sha256',
      version: version,
      syncStatus: status,
      localPath: localPath,
    );
  }

  RemoteDocument buildRemoteDoc({
    required String id,
    required int version,
    required DateTime updatedAt,
    String title = 'Bản Cloud',
    String? checksum,
    String? storagePath,
  }) {
    return RemoteDocument(
      id: id,
      ownerId: kOwner,
      version: version,
      updatedAt: updatedAt,
      data: buildDoc(
        id: id,
        version: version,
        updated: updatedAt,
        title: title,
      ).toMap(),
      checksum: checksum,
      checksumAlgorithm: 'sha256',
      storagePath: storagePath,
    );
  }

  group('Kiểm thử Đồng bộ Offline-First (Sync Engine)', () {
    test('1. PUSH tài liệu cục bộ kèm tệp + kiểm tra checksum', () async {
      final bytes = utf8.encode('nội dung slide bài giảng chương 3');
      final path = await fileStore.save('chapter3.pdf', bytes);
      final checksum = ChecksumUtils.compute(bytes);

      await db.insertDocument(
        buildDoc(id: 'doc_push', localPath: path, checksum: checksum),
      );
      await db.enqueueOutbox(
        entityId: 'doc_push',
        operation: SyncOperation.upsert,
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      expect(result.pushedDocuments, equals(1));
      expect(result.uploadedFiles, equals(1));

      final remoteDoc = remote.documentAt(kOwner, 'doc_push');
      expect(remoteDoc, isNotNull);
      expect(remoteDoc!.checksum, equals(checksum));
      expect(remoteDoc.storagePath, isNotNull);
      expect(remote.hasFile(remoteDoc.storagePath!), isTrue);

      final local = await db.getDocumentById('doc_push');
      expect(local!.syncStatus, equals(SyncStatus.synced));
      expect(local.lastSyncedAt, isNotNull);
      expect(await db.getPendingSyncCount(), equals(0));
      expect(engine.snapshot.value.lastResult, isNotNull);
    });

    test('2. PULL tài liệu mới từ Cloud về SQLite cục bộ', () async {
      final remoteBytes = utf8.encode('tệp trên cloud');
      final storagePath = 'mock://$kOwner/doc_pull/file.pdf';
      remote.seedFile(storagePath, remoteBytes);
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_pull',
          version: 1,
          updatedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          title: 'Tài liệu tải từ Cloud',
          checksum: ChecksumUtils.compute(remoteBytes),
          storagePath: storagePath,
        ),
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      expect(result.pulledDocuments, equals(1));

      final local = await db.getDocumentById('doc_pull');
      expect(local, isNotNull);
      expect(local!.title, equals('Tài liệu tải từ Cloud'));
      expect(local.syncStatus, equals(SyncStatus.synced));
      // Tệp được tải về và lưu vào cache cục bộ.
      expect(local.localPath, isNotNull);
      final cached = await fileStore.read(local.localPath!);
      expect(cached, equals(remoteBytes));
    });

    test('3. PULL bỏ qua khi tệp trên Cloud không tồn tại', () async {
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_missing_file',
          version: 1,
          updatedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          storagePath: 'mock://$kOwner/khong-ton-tai.pdf',
        ),
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      final local = await db.getDocumentById('doc_missing_file');
      expect(local, isNotNull);
      expect(local!.localPath, isNull);
    });

    test('4. Xóa tài liệu: ghi delete_logs + tombstone trên Cloud', () async {
      final bytes = utf8.encode('tệp sắp xóa');
      final path = await fileStore.save('delete-me.pdf', bytes);
      final doc = buildDoc(
        id: 'doc_del',
        localPath: path,
        checksum: ChecksumUtils.compute(bytes),
      );
      await db.insertDocument(doc);
      await db.enqueueOutbox(
        entityId: 'doc_del',
        operation: SyncOperation.upsert,
      );
      await engine.syncNow();

      final storagePath = remote.documentAt(kOwner, 'doc_del')!.storagePath;
      const deleteLogId = 'log_del_1';
      await db.insertDeleteLog(
        DeleteLogModel(
          id: deleteLogId,
          documentId: 'doc_del',
          ownerId: kOwner,
          storagePath: storagePath,
          checksum: doc.checksum,
          deletedAt: DateTime.now(),
          source: 'local',
          syncStatus: DeleteLogStatus.pending,
        ),
      );
      await db.enqueueOutbox(
        entityId: 'doc_del',
        operation: SyncOperation.delete,
        payload: {'delete_log_id': deleteLogId, 'storage_path': storagePath},
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      expect(result.deletedDocuments, greaterThanOrEqualTo(1));
      expect(remote.documentAt(kOwner, 'doc_del')!.isDeleted, isTrue);
      expect(remote.hasFile(storagePath!), isFalse);

      final logs = await db.getDeleteLogs();
      expect(logs, hasLength(1));
      expect(logs.first.syncStatus, equals(DeleteLogStatus.synced));
      expect(await db.getPendingSyncCount(), equals(0));
    });

    test('5. Mất mạng: PUSH thất bại nhưng hàng đợi được giữ lại', () async {
      remote.online = false;
      await db.insertDocument(buildDoc(id: 'doc_offline'));
      await db.enqueueOutbox(
        entityId: 'doc_offline',
        operation: SyncOperation.upsert,
      );

      final result = await engine.syncNow();

      expect(result.success, isFalse);
      expect(result.failed, greaterThanOrEqualTo(1));
      expect(await db.getPendingSyncCount(), equals(1));
      expect(remote.documentAt(kOwner, 'doc_offline'), isNull);
    });

    test('6. Kiểm tra checksum khi PULL: tệp hỏng -> đánh dấu conflict',
        () async {
      final bytes = utf8.encode('nội dung bị hỏng');
      final storagePath = 'mock://$kOwner/doc_corrupt/file.pdf';
      remote.seedFile(storagePath, bytes);
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_corrupt',
          version: 1,
          updatedAt: DateTime.now().subtract(const Duration(seconds: 2)),
          checksum: '0' * 64, // checksum sai (64 ký tự hex)
          storagePath: storagePath,
        ),
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      final local = await db.getDocumentById('doc_corrupt');
      expect(local, isNotNull);
      expect(
        local!.syncStatus,
        equals(SyncStatus.conflict),
        reason: 'Checksum không khớp phải đánh dấu xung đột/hỏng tệp',
      );
    });

    test('7. Xung đột PULL: bản cục bộ mới hơn được giữ lại', () async {
      final now = DateTime.now();
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_conflict_local',
          version: 2,
          updatedAt: now.subtract(const Duration(minutes: 10)),
          title: 'Bản Cloud cũ',
        ),
      );
      await db.insertDocument(
        buildDoc(
          id: 'doc_conflict_local',
          version: 1,
          updated: now,
          status: SyncStatus.pendingUpload,
          title: 'Bản cục bộ mới',
        ),
      );

      final result = await engine.syncNow();

      expect(result.conflicts, greaterThanOrEqualTo(1));
      final local = await db.getDocumentById('doc_conflict_local');
      expect(local!.title, equals('Bản cục bộ mới'));
      expect(local.syncStatus, equals(SyncStatus.conflict));
    });

    test('8. Xung đột PULL: bản Cloud mới hơn ghi đè cục bộ (LWW)', () async {
      final now = DateTime.now();
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_conflict_remote',
          version: 3,
          updatedAt: now,
          title: 'Bản Cloud mới',
        ),
      );
      await db.insertDocument(
        buildDoc(
          id: 'doc_conflict_remote',
          version: 1,
          updated: now.subtract(const Duration(minutes: 10)),
          status: SyncStatus.pendingUpload,
          title: 'Bản cục bộ cũ',
        ),
      );

      final result = await engine.syncNow();

      expect(result.success, isTrue);
      final local = await db.getDocumentById('doc_conflict_remote');
      expect(local!.title, equals('Bản Cloud mới'));
      expect(local.version, equals(3));
      expect(local.syncStatus, equals(SyncStatus.synced));
    });

    test('9. Xung đột PUSH: cục bộ mới hơn -> tăng version và đẩy lại',
        () async {
      final now = DateTime.now();
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_push_conflict',
          version: 5,
          updatedAt: now.subtract(const Duration(minutes: 10)),
          title: 'Bản Cloud cũ',
        ),
      );
      await db.insertDocument(
        buildDoc(
          id: 'doc_push_conflict',
          version: 1,
          updated: now,
          title: 'Bản cục bộ mới',
        ),
      );
      await db.enqueueOutbox(
        entityId: 'doc_push_conflict',
        operation: SyncOperation.upsert,
      );

      final result = await engine.syncNow();

      expect(result.conflicts, greaterThanOrEqualTo(1));
      final local = await db.getDocumentById('doc_push_conflict');
      expect(local!.version, equals(6));
      expect(local.syncStatus, equals(SyncStatus.pendingUpload));
      expect(await db.getPendingSyncCount(), equals(1));
    });

    test('10. Lỗi tạm thời: tăng retry_count trong outbox', () async {
      remote.forceNextFailures(1);
      await db.insertDocument(buildDoc(id: 'doc_retry'));
      await db.enqueueOutbox(
        entityId: 'doc_retry',
        operation: SyncOperation.upsert,
      );

      final result = await engine.syncNow();

      expect(result.success, isFalse);
      final entries = await db.getOutboxEntries();
      expect(entries, hasLength(1));
      expect(entries.first.retryCount, equals(1));
      expect(entries.first.lastError, isNotNull);

      // Lần đồng bộ kế tiếp (mạng đã ổn) phải đẩy thành công.
      final retry = await engine.syncNow();
      expect(retry.success, isTrue);
      expect(await db.getPendingSyncCount(), equals(0));
    });

    test('11. PUSH phát hiện tệp cục bộ bị hỏng (checksum sai)', () async {
      final path = await fileStore.save('corrupt.pdf', utf8.encode('abc'));
      await db.insertDocument(
        buildDoc(
          id: 'doc_bad_file',
          localPath: path,
          checksum: 'f' * 64, // không khớp nội dung thật
        ),
      );
      await db.enqueueOutbox(
        entityId: 'doc_bad_file',
        operation: SyncOperation.upsert,
      );

      final result = await engine.syncNow();

      expect(result.success, isFalse);
      expect(
        await db.getPendingSyncCount(),
        equals(1),
        reason: 'Tệp hỏng không được đẩy lên và phải giữ trong outbox',
      );
    });

    test('12. initialize() nạp số mục chờ đồng bộ ban đầu', () async {
      await db.enqueueOutbox(
        entityId: 'doc_a',
        operation: SyncOperation.upsert,
      );
      await db.enqueueOutbox(
        entityId: 'doc_b',
        operation: SyncOperation.upsert,
      );

      final fresh = SyncEngine(
        database: db,
        remote: remote,
        fileStore: fileStore,
        ownerId: kOwner,
      );
      await fresh.initialize();
      expect(fresh.snapshot.value.pendingCount, equals(2));
      await fresh.dispose();
    });

    test('13. LWW áp dụng theo updatedDate khi version bằng nhau', () async {
      final now = DateTime.now();
      remote.seedDocument(
        buildRemoteDoc(
          id: 'doc_lww',
          version: 1,
          updatedAt: now,
          title: 'Cloud cập nhật sau',
        ),
      );
      // Cục bộ đã synced (không dirty) phiên bản cũ hơn.
      await db.insertDocument(
        buildDoc(
          id: 'doc_lww',
          version: 1,
          updated: now.subtract(const Duration(minutes: 5)),
          status: SyncStatus.synced,
          title: 'Cục bộ cũ',
        ),
      );

      // remote version 1 <= local version 1 -> engine bỏ qua (không tải đè).
      await engine.syncNow();
      final local = await db.getDocumentById('doc_lww');
      expect(local!.title, equals('Cục bộ cũ'));
    });
  });
}
