import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:study_document_manager/colors.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/database/databaseGlobal.dart';
import 'package:study_document_manager/pages/add_edit_document_page.dart';
import 'package:study_document_manager/pages/document_detail_page.dart';
import 'package:study_document_manager/pages/document_list_page.dart';
import 'package:study_document_manager/pages/home_page.dart';
import 'package:study_document_manager/widgets/cloud/cloud_status_strip.dart';
import 'package:study_document_manager/widgets/cloud/transfer_progress_bar.dart';
import 'package:study_document_manager/widgets/cloud/user_profile_card.dart';

// =====================================================================
// [BỘ CÔNG CỤ CHỤP ẢNH MINH CHỨNG TỰ ĐỘNG - VŨ HẢI ĐĂNG]
// File: test/capture_screenshots_test.dart
// Mô tả: Kết xuất giao diện Flutter ra hình ảnh độ phân giải cao (PNG)
// phục vụ báo cáo minh chứng bài tập lớn (UI/UX, Cloud Sync, Upload Bar, Profile).
// =====================================================================

Future<void> _renderAndCapture(
  WidgetTester tester,
  Widget widget,
  String goldenName, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(),
      home: widget,
    ),
  );

  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../screenshots/$goldenName'),
  );
}

void main() {
  testWidgets('Minh chứng 1: Trang chủ Dashboard & Cloud Status', (
    tester,
  ) async {
    database = AppDatabase();
    await tester.runAsync(() => database.init(isInMemory: true));
    await tester.runAsync(() => database.notifyDocumentsChanged());
    addTearDown(() => tester.runAsync(() => database.close()));

    await _renderAndCapture(
      tester,
      const HomePage(),
      '01_home_dashboard.png',
    );
  });

  testWidgets('Minh chứng 2: Danh sách tài liệu danh mục (Đã khắc phục load)', (
    tester,
  ) async {
    database = AppDatabase();
    await tester.runAsync(() => database.init(isInMemory: true));
    await tester.runAsync(() => database.notifyDocumentsChanged());
    addTearDown(() => tester.runAsync(() => database.close()));

    await _renderAndCapture(
      tester,
      const DocumentListPage(initialSubjectId: 'sub_swe'),
      '02_category_documents.png',
    );
  });

  testWidgets('Minh chứng 3: Thêm mới tài liệu có mục Upload File bài tập', (
    tester,
  ) async {
    database = AppDatabase();
    await tester.runAsync(() => database.init(isInMemory: true));
    addTearDown(() => tester.runAsync(() => database.close()));

    await _renderAndCapture(
      tester,
      const AddEditDocumentPage(),
      '03_add_document_upload.png',
    );
  });

  testWidgets('Minh chứng 4: Thanh tiến trình tải tệp (Upload / Download Progress Bar)', (
    tester,
  ) async {
    await _renderAndCapture(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Tiến trình tải tệp Cloud')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Minh chứng thành phần Upload & Download Progress Bar (Vũ Hải Đăng)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const TransferProgressBar(
                isUpload: true,
                fileName: 'Bao_cao_Kien_truc_Phan_mem_Tuan_4.pdf',
                transferredBytes: 4200 * 1024,
                totalBytes: 6500 * 1024,
              ),
              const SizedBox(height: 16),
              const TransferProgressBar(
                isUpload: false,
                fileName: 'Giao_trinh_Clean_Architecture.pdf',
                transferredBytes: 12000 * 1024,
                totalBytes: 15400 * 1024,
              ),
              const SizedBox(height: 16),
              TransferProgressBar(
                isUpload: true,
                fileName: 'De_thi_thu_DSA.docx',
                transferredBytes: 1024 * 50,
                totalBytes: 1024 * 500,
                errorMessage: 'Mất kết nối mạng. Đang chờ thử lại...',
                onRetry: () {},
              ),
            ],
          ),
        ),
      ),
      '04_transfer_progress_bar.png',
    );
  });

  testWidgets('Minh chứng 5: Chi tiết tài liệu với Cloud Sync Badge & Tệp đính kèm', (
    tester,
  ) async {
    database = AppDatabase();
    await tester.runAsync(() => database.init(isInMemory: true));
    addTearDown(() => tester.runAsync(() => database.close()));

    await _renderAndCapture(
      tester,
      const DocumentDetailPage(documentId: 'doc_1'),
      '05_document_detail_cloud.png',
    );
  });

  testWidgets('Minh chứng 6: Giao diện thông tin người dùng (Avatar, Email, Tên hiển thị)', (
    tester,
  ) async {
    await _renderAndCapture(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Thông tin người dùng')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            UserProfileCard(
              displayName: 'Vũ Hải Đăng',
              email: 'haidang.vu@student.university.edu.vn',
              photoUrl: null,
              isSignedIn: true,
              isBusy: false,
              onSignIn: () {},
              onSignOut: () {},
            ),
            const SizedBox(height: 16),
            const CloudStatusStrip(),
          ],
        ),
      ),
      '06_user_profile.png',
    );
  });
}
