import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/checksum_utils.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/struct/models/sync_models.dart';
import 'package:study_document_manager/struct/sync/local_file_store.dart';
import 'package:study_document_manager/struct/sync/mock_remote_sync_service.dart';
import 'package:study_document_manager/struct/sync/sync_engine.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ HIỆU NĂNG MẠNG YẾU (WEAK-NETWORK PERF)]
// File: test/weak_network_perf_test.dart
// Mô tả: Đo thời gian truyền tải và thông lượng (throughput) của chu trình
// đồng bộ khi mô phỏng các hồ sơ mạng khác nhau (Lý tưởng / Wi-Fi / 3G yếu /
// Rất yếu) bằng MockRemoteSyncService. Kiểm chứng:
//   1. Mạng yếu làm tăng thời gian truyền tải và giảm thông lượng.
//   2. Mất gói tin khiến đồng bộ thất bại nhưng hàng đợi được giữ lại
//      và tự đồng bộ lại thành công khi mạng phục hồi.
// =====================================================================

/// Kết quả đo hiệu năng của một lần chạy đồng bộ.
class PerfResult {
  final String label;
  final Duration elapsed;
  final int docCount;
  final int totalBytes;
  final int transfers;
  final int failures;

  const PerfResult({
    required this.label,
    required this.elapsed,
    required this.docCount,
    required this.totalBytes,
    required this.transfers,
    required this.failures,
  });

  double get seconds => elapsed.inMicroseconds / 1000000.0;

  double get throughputKBps =>
      (totalBytes == 0 || elapsed.inMicroseconds == 0)
          ? 0
          : (totalBytes / 1024.0) / seconds;

  double get msPerDocument =>
      docCount == 0 ? 0 : elapsed.inMilliseconds / docCount;

  @override
  String toString() =>
      '$label: ${elapsed.inMilliseconds}ms, '
      '${throughputKBps.toStringAsFixed(1)} KB/s, '
      '${msPerDocument.toStringAsFixed(0)} ms/tài liệu, '
      '$transfers transfers, $failures lỗi';
}

/// Chạy chu trình PUSH+PULL với [docCount] tài liệu, mỗi tài liệu [fileSize] byte.
Future<PerfResult> runPipeline({
  required String label,
  required NetworkProfile profile,
  required int docCount,
  required int fileSize,
  required int seed,
}) async {
  final db = AppDatabase();
  await db.init(isInMemory: true);
  final remote = MockRemoteSyncService(profile: profile, seed: seed);
  final fileStore = InMemoryFileStore();
  final engine = SyncEngine(
    database: db,
    remote: remote,
    fileStore: fileStore,
    ownerId: 'perf-owner',
    // Chỉ đo chi phí PUSH tệp lên Cloud, không tải lại khi PULL.
    downloadRemoteFiles: false,
  );
  await engine.initialize();

  final bytes = List<int>.generate(fileSize, (i) => (i * 31 + seed) % 251);
  final checksum = ChecksumUtils.compute(bytes);

  for (var i = 0; i < docCount; i++) {
    final path = await fileStore.save('perf_$i.bin', bytes);
    final doc = DocumentModel(
      id: 'perf_$i',
      title: 'Tài liệu hiệu năng $i',
      subjectId: 'sub_swe',
      type: DocumentType.lecture,
      tags: const ['Perf'],
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
      checksum: checksum,
      checksumAlgorithm: 'sha256',
      version: 1,
      syncStatus: SyncStatus.pendingUpload,
      localPath: path,
    );
    await db.insertDocument(doc);
    await db.enqueueOutbox(
      entityId: doc.id,
      operation: SyncOperation.upsert,
    );
  }

  final stopwatch = Stopwatch()..start();
  final result = await engine.syncNow();
  stopwatch.stop();

  expect(
    result.success,
    isTrue,
    reason: '$label: đồng bộ phải thành công (${result.errors})',
  );
  expect(await db.getPendingSyncCount(), equals(0));

  final perf = PerfResult(
    label: label,
    elapsed: stopwatch.elapsed,
    docCount: docCount,
    totalBytes: bytes.length * docCount,
    transfers: remote.transferCount,
    failures: remote.failedTransfers,
  );

  await engine.dispose();
  await db.close();
  return perf;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Hồ sơ mạng yếu không mất gói để phép đo thời gian ổn định, tất định.
  const profileWeak3G = NetworkProfile(
    latency: Duration(milliseconds: 30),
    bandwidthBytesPerSecond: 48 * 1024, // ~48 KB/s
    packetLossRate: 0,
  );
  const profileVeryWeak = NetworkProfile(
    latency: Duration(milliseconds: 90),
    bandwidthBytesPerSecond: 12 * 1024, // ~12 KB/s
    packetLossRate: 0,
  );

  group('Kiểm thử hiệu năng truyền tải trên mạng yếu (Weak-Network Perf)', () {
    test('1. Mạng càng yếu thì thời gian đồng bộ càng lớn', () async {
      const docCount = 4;
      const fileSize = 4096; // 4 KB mỗi tài liệu

      final ideal = await runPipeline(
        label: 'Mạng lý tưởng',
        profile: NetworkProfile.ideal,
        docCount: docCount,
        fileSize: fileSize,
        seed: 1,
      );
      final weak = await runPipeline(
        label: '3G yếu (48KB/s, 30ms)',
        profile: profileWeak3G,
        docCount: docCount,
        fileSize: fileSize,
        seed: 1,
      );
      final veryWeak = await runPipeline(
        label: 'Rất yếu (12KB/s, 90ms)',
        profile: profileVeryWeak,
        docCount: docCount,
        fileSize: fileSize,
        seed: 1,
      );

      // In bảng kết quả để đính kèm báo cáo.
      // ignore: avoid_print
      print('\n===== BẢNG HIỆU NĂNG TRUYỀN TẢI (4 tài liệu x 4KB) =====');
      for (final r in [ideal, weak, veryWeak]) {
        // ignore: avoid_print
        print('  $r');
      }
      // ignore: avoid_print
      print('==========================================================\n');

      // Cùng một khối lượng công việc trên mọi hồ sơ mạng.
      expect(weak.transfers, equals(veryWeak.transfers));
      expect(ideal.failures, equals(0));
      expect(weak.failures, equals(0));

      // Mạng yếu tốn nhiều thời gian hơn mạng lý tưởng.
      expect(
        weak.elapsed.inMilliseconds,
        greaterThan(ideal.elapsed.inMilliseconds),
        reason: '3G yếu phải chậm hơn mạng lý tưởng',
      );
      expect(
        veryWeak.elapsed.inMilliseconds,
        greaterThan(weak.elapsed.inMilliseconds),
        reason: 'Mạng rất yếu phải chậm hơn 3G yếu',
      );

      // Thông lượng (KB/s) giảm dần theo độ yếu của mạng.
      if (weak.throughputKBps > 0 && veryWeak.throughputKBps > 0) {
        expect(
          weak.throughputKBps,
          greaterThan(veryWeak.throughputKBps),
          reason: 'Thông lượng 3G yếu phải cao hơn mạng rất yếu',
        );
      }
    });

    test('2. Mạng lý tưởng gần như tức thời (không có độ trễ)', () async {
      final ideal = await runPipeline(
        label: 'Mạng lý tưởng',
        profile: NetworkProfile.ideal,
        docCount: 3,
        fileSize: 2048,
        seed: 2,
      );
      expect(ideal.elapsed.inMilliseconds, lessThan(500));
    });

    test('3. Mất gói: đồng bộ lỗi nhưng giữ hàng đợi, phục hồi khi có mạng',
        () async {
      final db = AppDatabase();
      await db.init(isInMemory: true);
      final remote = MockRemoteSyncService(
        profile: const NetworkProfile(packetLossRate: 1.0),
        seed: 7,
      );
      final fileStore = InMemoryFileStore();
      final engine = SyncEngine(
        database: db,
        remote: remote,
        fileStore: fileStore,
        ownerId: 'perf-owner',
      );
      await engine.initialize();

      final bytes = List<int>.generate(1024, (i) => i % 256);
      final path = await fileStore.save('loss.bin', bytes);
      await db.insertDocument(
        DocumentModel(
          id: 'loss_doc',
          title: 'Tài liệu mất gói',
          subjectId: 'sub_swe',
          type: DocumentType.lecture,
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
          checksum: ChecksumUtils.compute(bytes),
          checksumAlgorithm: 'sha256',
          version: 1,
          syncStatus: SyncStatus.pendingUpload,
          localPath: path,
        ),
      );
      await db.enqueueOutbox(
        entityId: 'loss_doc',
        operation: SyncOperation.upsert,
      );

      // 100% mất gói -> đồng bộ thất bại, hàng đợi vẫn còn nguyên.
      final failed = await engine.syncNow();
      expect(failed.success, isFalse);
      expect(failed.failed, greaterThanOrEqualTo(1));
      expect(remote.failedTransfers, greaterThan(0));
      expect(await db.getPendingSyncCount(), equals(1));

      // Mạng phục hồi -> tự động đẩy thành công, hàng đợi rỗng.
      remote.profile = NetworkProfile.ideal;
      final recovered = await engine.syncNow();
      expect(recovered.success, isTrue);
      expect(await db.getPendingSyncCount(), equals(0));
      expect(remote.documentAt('perf-owner', 'loss_doc'), isNotNull);

      await engine.dispose();
      await db.close();
    });

    test('4. Hồ sơ mạng có nhãn mô tả đúng (NetworkProfile)', () {
      expect(NetworkProfile.ideal.label, equals('Lý tưởng'));
      expect(NetworkProfile.wifi.label, equals('Wi-Fi'));
      expect(NetworkProfile.weak3G.label, equals('3G yếu'));
      expect(NetworkProfile.veryWeak.label, equals('Rất yếu (2G)'));
      expect(profileWeak3G.label, equals('Tùy chỉnh'));
      expect(NetworkProfile.veryWeak.unlimitedBandwidth, isFalse);
      expect(NetworkProfile.ideal.unlimitedBandwidth, isTrue);
    });
  });
}
