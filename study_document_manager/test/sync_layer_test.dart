import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/struct/sync/checksum_util.dart';
import 'package:study_document_manager/struct/sync/connectivity_monitor.dart';
import 'package:study_document_manager/struct/sync/file_cache_store.dart';
import 'package:study_document_manager/struct/sync/offline_sync_service.dart';
import 'package:study_document_manager/struct/sync/sync_backend.dart';
import 'package:study_document_manager/struct/sync/sync_models.dart';
import 'package:study_document_manager/struct/sync/sync_status.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ TẦNG ĐỒNG BỘ (OFFLINE SYNC LAYER TEST)]
// File: test/sync_layer_test.dart
// Mô tả: Kiểm tra cơ chế Task 2 (nhánh son-offline-sync):
//  1. Local Cache kết hợp Cloud.
//  2. Tự động đồng bộ hai chiều khi mạng trở lại.
//  3. Kiểm tra tính toàn vẹn tệp (Checksum MD5/SHA-256).
//  4. Cập nhật bảng delete_logs (tombstone).
//  5. Hiệu năng truyền tải khi mạng yếu (latency/bandwidth/retry/timeout).
// =====================================================================

/// Dừng lặp cho tới khi [condition] đúng (có timeout an toàn).
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String reason = 'Điều kiện',
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('$reason không đạt trong $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

DocumentModel makeDoc({
  String id = 'doc_test',
  String? title,
  DateTime? updatedDate,
  DateTime? createdDate,
}) {
  final now = DateTime.now();
  return DocumentModel(
    id: id,
    title: title ?? 'Tài liệu $id',
    subjectId: 'sub_swe',
    type: DocumentType.lecture,
    notes: 'Notes $id',
    fileUrl: 'https://example.com/$id.pdf',
    tags: ['Test'],
    isFavorite: false,
    createdDate: createdDate ?? now,
    updatedDate: updatedDate ?? now,
  );
}

RemoteDocument makeRemote({
  required String id,
  String? title,
  DateTime? updatedDate,
  DateTime? createdDate,
  int remoteVersion = 1,
  String? checksum,
  int? fileSize,
}) {
  final now = DateTime.now();
  return RemoteDocument(
    id: id,
    title: title ?? 'Remote $id',
    subjectId: 'sub_swe',
    type: 'lecture',
    notes: 'notes',
    createdDate: createdDate ?? now,
    updatedDate: updatedDate ?? now,
    remoteVersion: remoteVersion,
    checksum: checksum,
    fileSize: fileSize,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =================================================================
  // NHÓM A: TIỆN ÍCH BĂM & TÍNH TOÀN VẸN TỆP
  // =================================================================
  group('A. Kiểm thử Checksum (MD5 / SHA-256) & tính toàn vẹn tệp', () {
    test('A1. SHA-256 chuẩn NIST cho "abc"', () {
      expect(
        ChecksumUtil.computeText('abc'),
        equals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
      );
    });

    test('A2. MD5 chuẩn cho "abc"', () {
      expect(
        ChecksumUtil.md5Hex('abc'.codeUnits),
        equals('900150983cd24fb0d6963f7d28e17f72'),
      );
    });

    test('A3. Kiểm tra toàn vẹn verify() đúng/sai', () {
      final content = List<int>.generate(1024, (i) => i % 251);
      final checksum = ChecksumUtil.sha256Hex(content);
      expect(ChecksumUtil.verify(content, checksum), isTrue);

      final corrupted = List<int>.from(content);
      corrupted[100] = (corrupted[100] + 1) % 251;
      expect(ChecksumUtil.verify(corrupted, checksum), isFalse,
          reason: 'Sửa 1 byte là checksum phải khác');
    });

    test('A4. Băm 2 nội dung khác nhau cho kết quả khác nhau', () {
      expect(
        ChecksumUtil.sha256Hex([1, 2, 3]),
        isNot(equals(ChecksumUtil.sha256Hex([1, 2, 4]))),
      );
    });
  });

  // =================================================================
  // NHÓM B: TẦNG DỮ LIỆU OFFLINE (SQLite + delete_logs)
  // =================================================================
  group('B. Kiểm thử Local Cache trên SQLite + bảng delete_logs', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase();
      await db.init(isInMemory: true);
    });

    tearDown(() async {
      await db.close();
    });

    test('B1. Thêm mới tài liệu offline -> sync_status = pendingCreate', () async {
      await db.insertDocument(makeDoc(id: 'b1'));
      final saved = await db.getDocumentById('b1');
      expect(saved, isNotNull);
      expect(saved!.syncStatus, SyncStatus.pendingCreate);
    });

    test('B2. Cập nhật tài liệu -> pendingUpdate', () async {
      await db.insertDocument(makeDoc(id: 'b2'), markPending: false);
      await db.updateDocument(makeDoc(id: 'b2', title: 'Đã sửa'));
      final saved = await db.getDocumentById('b2');
      expect(saved!.title, 'Đã sửa');
      expect(saved.syncStatus, SyncStatus.pendingUpdate);
    });

    test('B3. Xóa tài liệu -> ghi tombstone vào delete_logs', () async {
      await db.insertDocument(makeDoc(id: 'b3'), markPending: false);
      await db.deleteDocument('b3');

      expect(await db.getDocumentById('b3'), isNull);
      final logs = await db.getAllDeleteLogs();
      expect(logs, hasLength(1));
      expect(logs.single.documentId, 'b3');
      expect(logs.single.synced, isFalse);
      expect(logs.single.deletedAt.isBefore(DateTime.now().add(const Duration(seconds: 1))),
          isTrue);
    });

    test('B4. applyRemoteDocument đánh dấu synced và KHÔNG đổi updated_date', () async {
      final fixed = DateTime(2026, 3, 1, 8, 0, 0);
      await db.applyRemoteDocument(makeDoc(id: 'b4', updatedDate: fixed), remoteVersion: 9);

      final saved = await db.getDocumentById('b4');
      expect(saved!.syncStatus, SyncStatus.synced);
      expect(saved.remoteVersion, 9);
      expect(saved.lastSyncedAt, isNotNull);

      await db.markDocumentSynced('b4', remoteVersion: 10);
      final after = await db.getDocumentById('b4');
      expect(after!.updatedDate, fixed, reason: 'Đồng bộ không được làm mới updated_date');
      expect(after.remoteVersion, 10);
    });

    test('B5. Đếm số bản ghi chờ đồng bộ', () async {
      await db.insertDocument(makeDoc(id: 'b5a'));
      await db.insertDocument(makeDoc(id: 'b5b'), markPending: false);
      await db.deleteDocument('b5b'); // tạo 1 tombstone
      final pending = await db.countPendingSyncChanges();
      expect(pending, 2); // 1 tài liệu + 1 tombstone
    });

    test('B6. Lưu/đọc mốc thời gian đồng bộ', () async {
      final marker = DateTime(2026, 6, 15, 12, 0, 0);
      await db.setLastSyncAt(marker);
      expect(await db.getLastSyncAt(), marker);
    });
  });

  // =================================================================
  // NHÓM C: ĐỒNG BỘ HAI CHIỀU (OFFLINE SYNC SERVICE)
  // =================================================================
  group('C. Kiểm thử OfflineSyncService (hai chiều, tự động, toàn vẹn)', () {
    late AppDatabase db;
    late InMemorySyncBackend backend;
    late MemoryFileCacheStore cache;
    late ManualConnectivityMonitor monitor;
    late OfflineSyncService service;

    OfflineSyncService createService({
      int maxRetries = 3,
      Duration retryDelay = const Duration(milliseconds: 10),
      Duration timeout = const Duration(seconds: 30),
    }) {
      return OfflineSyncService(
        db: db,
        backend: backend,
        connectivity: monitor,
        fileCache: cache,
        maxRetries: maxRetries,
        retryDelay: retryDelay,
        operationTimeout: timeout,
      );
    }

    setUp(() async {
      db = AppDatabase();
      await db.init(isInMemory: true);
      backend = InMemorySyncBackend();
      cache = MemoryFileCacheStore();
      monitor = ManualConnectivityMonitor(initiallyOnline: true);
      service = createService();
    });

    tearDown(() async {
      await service.dispose();
      await db.close();
    });

    test('C1. Đẩy tài liệu tạo offline lên Cloud khi mạng trở lại', () async {
      monitor.goOffline();
      await db.insertDocument(makeDoc(id: 'c1', title: 'Tạo khi offline'));
      monitor.goOnline();

      final report = await service.syncNow();
      expect(report.success, isTrue);
      expect(report.pushedDocuments, 1);

      final remote = backend.remoteDocument('c1');
      expect(remote, isNotNull);
      expect(remote!.title, 'Tạo khi offline');

      final local = await db.getDocumentById('c1');
      expect(local!.syncStatus, SyncStatus.synced);
      expect(await db.getPendingDocuments(), isEmpty);
    });

    test('C2. Kéo tài liệu mới từ Cloud xuống Local Cache', () async {
      backend.seedRemoteDocument(
        makeRemote(id: 'c2', title: 'Tài liệu từ Cloud', remoteVersion: 3),
      );

      final report = await service.syncNow();
      expect(report.success, isTrue);
      expect(report.pulledDocuments, 1);

      final local = await db.getDocumentById('c2');
      expect(local, isNotNull);
      expect(local!.title, 'Tài liệu từ Cloud');
      expect(local.syncStatus, SyncStatus.synced);
      expect(local.remoteVersion, 3);
    });

    test('C3. Xóa offline -> tombstone đẩy lên, Cloud xóa tài liệu + tệp', () async {
      // Chuẩn bị: tài liệu đã tồn tại cả 2 nơi.
      final remote = makeRemote(id: 'c3', title: 'Sẽ bị xóa', remoteVersion: 2);
      backend.seedRemoteDocument(remote);
      final content = List<int>.generate(512, (i) => i % 251);
      await backend.uploadFile('c3', ChecksumUtil.sha256Hex(content), content);
      await db.applyRemoteDocument(makeDoc(id: 'c3', title: 'Sẽ bị xóa'));
      await db.setLastSyncAt(remote.updatedDate);

      // Xóa khi OFFLINE: chỉ ghi tombstone cục bộ.
      monitor.goOffline();
      await db.deleteDocument('c3');
      expect((await db.getAllDeleteLogs()).single.synced, isFalse);

      monitor.goOnline();
      final report = await service.syncNow();

      expect(report.success, isTrue);
      expect(report.pushedDeletes, 1);
      expect(backend.remoteDocument('c3'), isNull, reason: 'Cloud không còn tài liệu');
      expect(await db.getDocumentById('c3'), isNull);
      expect(await db.getPendingDeleteLogs(), isEmpty, reason: 'Tombstone đã đồng bộ');
    });

    test('C4. LWW - bản cục bộ mới hơn thắng (Local Wins)', () async {
      final now = DateTime.now();
      await db.insertDocument(makeDoc(id: 'c4', title: 'Bản cục bộ MỚI', updatedDate: now.add(const Duration(hours: 2))));
      backend.seedRemoteDocument(
        makeRemote(id: 'c4', title: 'Bản Cloud CŨ', updatedDate: now.subtract(const Duration(hours: 1))),
      );

      final report = await service.syncNow();
      expect(report.success, isTrue);

      final remote = backend.remoteDocument('c4');
      expect(remote!.title, 'Bản cục bộ MỚI', reason: 'Bản cục bộ mới hơn phải được đẩy lên Cloud');
      final local = await db.getDocumentById('c4');
      expect(local!.syncStatus, SyncStatus.synced);
    });

    test('C5. LWW - bản Cloud mới hơn thắng (Remote Wins)', () async {
      final now = DateTime.now();
      await db.insertDocument(makeDoc(id: 'c5', title: 'Bản cục bộ CŨ', updatedDate: now.subtract(const Duration(hours: 1))));
      backend.seedRemoteDocument(
        makeRemote(id: 'c5', title: 'Bản Cloud MỚI', updatedDate: now.add(const Duration(hours: 2))),
      );

      final report = await service.syncNow();
      expect(report.success, isTrue);
      expect(report.conflicts, 1);

      final local = await db.getDocumentById('c5');
      expect(local!.title, 'Bản Cloud MỚI', reason: 'Bản Cloud mới hơn phải được giữ');
      expect(local.syncStatus, SyncStatus.synced);
      final remote = backend.remoteDocument('c5');
      expect(remote!.title, 'Bản Cloud MỚI');
    });

    test('C6. Đồng bộ FILE: upload tệp cục bộ và tải về khi thiếu (checksum khớp)', () async {
      final content = List<int>.generate(4096, (i) => i % 251);
      final checksum = ChecksumUtil.sha256Hex(content);
      final doc = makeDoc(id: 'c6', title: 'Có tệp đính kèm');
      await db.insertDocument(doc);
      await cache.write('c6', content);

      final report = await service.syncNow();
      expect(report.uploadedFiles, 1);
      expect(report.bytesUploaded, content.length);

      // Xác minh tệp trên Cloud còn nguyên vẹn.
      final fromCloud = await backend.downloadFile('c6', checksum);
      expect(fromCloud, isNotNull);
      expect(ChecksumUtil.verify(fromCloud!, checksum), isTrue);

      // Thiết lập tài liệu mới phía Cloud có tệp, máy cục bộ chưa có.
      await cache.delete('c6');
      backend.seedRemoteDocument(
        makeRemote(id: 'c7', title: 'Tệp từ Cloud', checksum: checksum, fileSize: content.length, remoteVersion: 1),
      );
      await backend.uploadFile('c7', checksum, content);

      final report2 = await service.syncNow();
      expect(report2.downloadedFiles, 1);
      final localBytes = await cache.read('c7');
      expect(localBytes, isNotNull);
      expect(ChecksumUtil.verify(localBytes!, checksum), isTrue);
    });

    test('C7. Tự động đồng bộ khi mạng trở lại (auto sync)', () async {
      monitor.goOffline();
      await service.startAutoSync(); // đang offline nên chưa đồng bộ

      await db.insertDocument(makeDoc(id: 'c8', title: 'Auto sync offline'));
      expect(backend.remoteDocument('c8'), isNull);

      monitor.goOnline(); // mạng trở lại -> kích hoạt đồng bộ tự động
      await waitUntil(() => backend.remoteDocument('c8') != null,
          reason: 'Tài liệu phải được đẩy lên Cloud sau khi mạng trở lại');

      final local = await db.getDocumentById('c8');
      expect(local!.syncStatus, SyncStatus.synced);
      expect(service.state.value.lastError, isNull);
    });

    test('C8. Đồng bộ lần 2 chỉ kéo phần mới (incremental since)', () async {
      // Lần 1: kéo toàn bộ.
      backend.seedRemoteDocument(
        makeRemote(id: 'c9a', title: 'Cũ', updatedDate: DateTime.now().subtract(const Duration(minutes: 5)), remoteVersion: 1),
      );
      var report = await service.syncNow();
      expect(report.pulledDocuments, 1);

      final afterFirst = await db.getLastSyncAt();
      expect(afterFirst, isNotNull);

      // Thêm tài liệu mới phía Cloud.
      backend.seedRemoteDocument(
        makeRemote(id: 'c9b', title: 'Mới', updatedDate: DateTime.now(), remoteVersion: 2),
      );
      report = await service.syncNow();
      expect(report.pulledDocuments, 1, reason: 'Chỉ tài liệu mới được kéo');
      expect(await db.getDocumentById('c9b'), isNotNull);
      expect(await db.getDocumentById('c9a'), isNotNull);
    });
  });

  // =================================================================
  // NHÓM D: HIỆU NĂNG TRUYỀN TẢI KHI MẠNG YẾU
  // =================================================================
  group('D. Kiểm thử hiệu năng khi mạng yếu (latency / bandwidth / retry)', () {
    late AppDatabase db;
    late InMemorySyncBackend backend;
    late MemoryFileCacheStore cache;
    late ManualConnectivityMonitor monitor;

    OfflineSyncService createService({
      int maxRetries = 3,
      Duration retryDelay = const Duration(milliseconds: 10),
      Duration timeout = const Duration(seconds: 30),
    }) {
      return OfflineSyncService(
        db: db,
        backend: backend,
        connectivity: monitor,
        fileCache: cache,
        maxRetries: maxRetries,
        retryDelay: retryDelay,
        operationTimeout: timeout,
      );
    }

    setUp(() async {
      db = AppDatabase();
      await db.init(isInMemory: true);
      backend = InMemorySyncBackend();
      cache = MemoryFileCacheStore();
      monitor = ManualConnectivityMonitor(initiallyOnline: true);
    });

    tearDown(() async {
      await db.close();
    });

    test('D1. Đo hiệu năng truyền tải với băng thông hạn chế', () async {
      backend.latency = const Duration(milliseconds: 30);
      backend.bytesPerSecond = 200000; // ~200 KB/s (mạng chậm)
      final service = createService();

      final content = List<int>.generate(100000, (i) => i % 251); // ~100 KB
      await db.insertDocument(makeDoc(id: 'd1', title: 'Tệp lớn'));
      await cache.write('d1', content);

      final report = await service.syncNow();
      expect(report.success, isTrue);
      expect(report.uploadedFiles, 1);
      expect(report.bytesUploaded, content.length);
      expect(report.duration.inMilliseconds, greaterThan(100),
          reason: 'Mạng yếu phải làm tăng thời gian truyền tải');
      expect(report.throughputBytesPerSecond, greaterThan(0));
      expect(
        report.throughputBytesPerSecond,
        lessThanOrEqualTo(backend.bytesPerSecond * 1.5),
        reason: 'Thông lượng không thể vượt quá băng thông mô phỏng (có sai số đo)',
      );
      await service.dispose();
    });

    test('D2. Retry tự động khi mạng chập chờn (lỗi thoáng qua)', () async {
      backend.failNext(2); // 2 lần gọi đầu bị lỗi mạng
      final service = createService(maxRetries: 5);

      await db.insertDocument(makeDoc(id: 'd2', title: 'Retry test'));
      final report = await service.syncNow();

      expect(report.success, isTrue);
      expect(report.attempts, greaterThan(1), reason: 'Phải có ít nhất 1 lần thử lại');
      expect(backend.remoteDocument('d2'), isNotNull, reason: 'Cuối cùng phải đẩy thành công');
      await service.dispose();
    });

    test('D3. Thất bại khi mạng yếu kéo dài (hết số lần retry)', () async {
      backend.failNext(100); // mạng hỏng liên tục
      final service = createService(maxRetries: 2, retryDelay: const Duration(milliseconds: 5));

      await db.insertDocument(makeDoc(id: 'd3'));
      final report = await service.syncNow();

      expect(report.success, isFalse);
      expect(report.attempts, greaterThanOrEqualTo(2));
      expect(backend.remoteDocument('d3'), isNull);
      await service.dispose();
    });

    test('D4. Timeout khi thao tác Cloud quá chậm (không treo vô hạn)', () async {
      backend.latency = const Duration(seconds: 30);
      final service = createService(
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 5),
        timeout: const Duration(milliseconds: 50),
      );

      await db.insertDocument(makeDoc(id: 'd4'));
      final report = await service.syncNow();

      expect(report.success, isFalse);
      expect(report.duration.inMilliseconds, lessThan(3000),
          reason: 'Không được treo lâu khi mạng chậm');
      await service.dispose();
    });

    test('D5. Offline -> syncNow trả về báo cáo offline, thay đổi được giữ lại', () async {
      backend.online = false;
      monitor.goOffline();
      final service = createService();

      await db.insertDocument(makeDoc(id: 'd5', title: 'Giữ khi offline'));
      final report = await service.syncNow();

      expect(report.skippedOffline, isTrue);
      expect(await db.getDocumentById('d5'), isNotNull);
      expect((await db.getDocumentById('d5'))!.syncStatus, SyncStatus.pendingCreate);
      expect(backend.remoteDocument('d5'), isNull);
      await service.dispose();
    });
  });

  // =================================================================
  // NHÓM E: DTO CHUYỂN ĐỔI (ROUND-TRIP)
  // =================================================================
  group('E. Kiểm thử chuyển đổi DTO (RemoteDocument / DeleteLogEntry)', () {
    test('E1. RemoteDocument <-> Map round-trip', () {
      final original = RemoteDocument(
        id: 'e1',
        title: 'Tài liệu E1',
        subjectId: 'sub_mob',
        type: 'assignment',
        tags: ['a', 'b'],
        isFavorite: true,
        priority: 2,
        deadline: DateTime(2026, 12, 31),
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
        checksum: 'abc123',
        fileSize: 1234,
        remoteVersion: 7,
      );

      final restored = RemoteDocument.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.type, 'assignment');
      expect(restored.tags, ['a', 'b']);
      expect(restored.deadline, original.deadline);
      expect(restored.createdDate, original.createdDate);
      expect(restored.updatedDate, original.updatedDate);
      expect(restored.checksum, 'abc123');
      expect(restored.fileSize, 1234);
      // toCloudMap không bao gồm trường nội bộ remote_version.
      expect(original.toCloudMap().containsKey('remote_version'), isFalse);
    });

    test('E2. DeleteLogEntry <-> Map round-trip', () {
      final original = DeleteLogEntry(
        id: 'log_e2',
        documentId: 'doc_e2',
        deletedAt: DateTime(2026, 5, 5, 10, 30),
        deviceId: 'device-1',
        synced: true,
        checksum: 'deadbeef',
        remotePurgedAt: DateTime(2026, 5, 6),
      );
      final restored = DeleteLogEntry.fromMap(original.toMap());
      expect(restored.id, 'log_e2');
      expect(restored.documentId, 'doc_e2');
      expect(restored.deletedAt, original.deletedAt);
      expect(restored.synced, isTrue);
      expect(restored.checksum, 'deadbeef');
      expect(restored.remotePurgedAt, original.remotePurgedAt);
    });

    test('E3. sync_status parse an toàn với dữ liệu cũ', () {
      expect(SyncStatusExtension.fromString('pendingCreate'), SyncStatus.pendingCreate);
      expect(SyncStatusExtension.fromString('pendingUpdate'), SyncStatus.pendingUpdate);
      expect(SyncStatusExtension.fromString('pendingDelete'), SyncStatus.pendingDelete);
      expect(SyncStatusExtension.fromString('synced'), SyncStatus.synced);
      expect(SyncStatusExtension.fromString(null), SyncStatus.synced);
      expect(SyncStatusExtension.fromString('không-hợp-lệ'), SyncStatus.synced);
    });
  });
}