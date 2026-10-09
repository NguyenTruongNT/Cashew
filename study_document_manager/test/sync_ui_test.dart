import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/sync/local_file_store.dart';
import 'package:study_document_manager/struct/sync/mock_remote_sync_service.dart';
import 'package:study_document_manager/struct/sync/sync_engine.dart';
import 'package:study_document_manager/struct/sync/sync_global.dart';
import 'package:study_document_manager/widgets/sync_status_banner.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ GIAO DIỆN TRẠNG THÁI ĐỒNG BỘ (SYNC UI)]
// File: test/sync_ui_test.dart
// Mô tả: Kiểm chứng thẻ SyncStatusBanner phản ánh đúng trạng thái đồng bộ
// (ngoại tuyến, đang chờ, đã đồng bộ) và có nút đồng bộ thủ công.
// =====================================================================

void main() {
  setUp(() => syncEngine = null);

  testWidgets('1. Không có SyncEngine -> hiển thị "Chỉ lưu cục bộ"', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncStatusBanner())),
    );
    expect(find.text('Chỉ lưu cục bộ'), findsOneWidget);
  });

  testWidgets('2. Ngoại tuyến -> báo "Đang ngoại tuyến" và số mục chờ', (
    tester,
  ) async {
    final db = AppDatabase();
    await tester.runAsync(() => db.init(isInMemory: true));
    final engine = SyncEngine(
      database: db,
      remote: MockRemoteSyncService(),
      fileStore: InMemoryFileStore(),
      ownerId: 'ui-owner',
    );
    engine.snapshot.value = const SyncSnapshot(
      isOnline: false,
      pendingCount: 3,
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SyncStatusBanner(engine: engine))),
    );

    expect(find.text('Đang ngoại tuyến'), findsOneWidget);
    expect(find.textContaining('3 thay đổi'), findsOneWidget);

    await tester.runAsync(() async {
      await engine.dispose();
      await db.close();
    });
  });

  testWidgets('3. Chờ đồng bộ -> hiển thị số mục và nút "Đồng bộ ngay"', (
    tester,
  ) async {
    final db = AppDatabase();
    await tester.runAsync(() => db.init(isInMemory: true));
    final engine = SyncEngine(
      database: db,
      remote: MockRemoteSyncService(),
      fileStore: InMemoryFileStore(),
      ownerId: 'ui-owner',
    );
    engine.snapshot.value = const SyncSnapshot(
      isOnline: true,
      pendingCount: 2,
    );

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncStatusBanner(
            engine: engine,
            onSyncNow: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.textContaining('2 mục chờ đồng bộ'), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

    // Bấm nút đồng bộ thủ công -> gọi đúng callback.
    await tester.tap(find.byIcon(Icons.sync_rounded));
    await tester.pump();
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      await engine.dispose();
      await db.close();
    });
  });

  testWidgets('4. Đã đồng bộ -> hiển thị "Đã đồng bộ Cloud"', (tester) async {
    final db = AppDatabase();
    await tester.runAsync(() => db.init(isInMemory: true));
    final engine = SyncEngine(
      database: db,
      remote: MockRemoteSyncService(),
      fileStore: InMemoryFileStore(),
      ownerId: 'ui-owner',
    );
    engine.snapshot.value = SyncSnapshot(
      isOnline: true,
      pendingCount: 0,
      lastSyncAt: DateTime(2026, 10, 3, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SyncStatusBanner(engine: engine))),
    );

    expect(find.text('Đã đồng bộ Cloud'), findsOneWidget);
    expect(find.textContaining('03/10/2026'), findsOneWidget);

    await tester.runAsync(() async {
      await engine.dispose();
      await db.close();
    });
  });
}
