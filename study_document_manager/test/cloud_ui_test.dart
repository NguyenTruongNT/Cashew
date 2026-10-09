import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/struct/firebase_storage_service.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/widgets/document_card.dart';
import 'package:study_document_manager/widgets/cloud/user_profile_card.dart';
import 'package:study_document_manager/widgets/cloud/transfer_progress_bar.dart';
import 'package:study_document_manager/widgets/cloud/cloud_sync_badge.dart';

void main() {
  group('Cloud UI', () {
    testWidgets('shows a Google sign-in action without a profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserProfileCard(
              displayName: null,
              email: null,
              photoUrl: null,
              isSignedIn: false,
              isBusy: false,
              onSignIn: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );

      expect(find.text('Tài khoản Google'), findsOneWidget);
      expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('shows the signed-in name and email', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserProfileCard(
              displayName: 'Nguyen Van A',
              email: 'student@example.edu',
              photoUrl: null,
              isSignedIn: true,
              isBusy: false,
              onSignIn: () {},
              onSignOut: () {},
            ),
          ),
        ),
      );

      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('student@example.edu'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });

    testWidgets('marks shared documents as read-only', (tester) async {
      final document = DocumentModel(
        id: 'shared_doc',
        title: 'Bài giảng dùng chung',
        subjectId: 'shared_subject',
        type: DocumentType.lecture,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
        isShared: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DocumentCard(document: document)),
        ),
      );

      expect(find.text('Chung'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    });

    test('encodes Firebase Storage paths separately from normal URLs', () {
      const path = 'users/user-1/documents/doc-1/lecture_notes.pdf';
      final storedValue = FirebaseStorageService.valueForPath(path);

      expect(FirebaseStorageService.isStorageValue(storedValue), isTrue);
      expect(FirebaseStorageService.pathFromValue(storedValue), path);
      expect(
        FirebaseStorageService.isStorageValue('https://example.com/a.pdf'),
        isFalse,
      );
      expect(
        FirebaseStorageService.fileNameFromPath(path),
        'lecture_notes.pdf',
      );
    });

    test('cleanly extracts file name from local attachment URLs (new and legacy)', () {
      // 1. New format with encoded filename in path
      final newUrl = FirebaseStorageService.saveLocalAttachment(
        documentId: 'doc_123',
        fileName: '02_bootshorthandout.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      expect(
        FirebaseStorageService.fileNameFromPath(newUrl),
        '02_bootshorthandout.pdf',
      );
      final decoded = FirebaseStorageService.decodeLocalAttachment(newUrl);
      expect(decoded, isNotNull);
      expect(decoded!.fileName, '02_bootshorthandout.pdf');
      expect(decoded.bytes, equals([1, 2, 3]));

      // 2. Legacy format with documentId prefix and underscores
      const legacyUrl =
          'local-attachment://att_assignment_eeptofljufrnnfv4smg4yvpkemrtwuyxb0vmmq_02_bootshorthandout.pdf';
      expect(
        FirebaseStorageService.fileNameFromPath(legacyUrl),
        '02_bootshorthandout.pdf',
      );

      // 3. Web URL
      const webUrl = 'https://example.com/files/slide_01.pptx?access_token=xyz';
      expect(FirebaseStorageService.fileNameFromPath(webUrl), 'slide_01.pptx');
    });

    testWidgets('TransferProgressBar displays progress percentage and bytes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransferProgressBar(
              isUpload: true,
              fileName: 'assignment_report.pdf',
              transferredBytes: 512 * 1024,
              totalBytes: 1024 * 1024,
            ),
          ),
        ),
      );

      expect(find.text('Đang tải tệp lên Cloud...'), findsOneWidget);
      expect(find.text('assignment_report.pdf'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('512.0 KB / 1.00 MB'), findsOneWidget);
    });

    testWidgets('TransferProgressBar offers retry for failed uploads', (
      tester,
    ) async {
      var retryCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransferProgressBar(
              isUpload: true,
              fileName: 'assignment_report.pdf',
              transferredBytes: 1024,
              totalBytes: 4096,
              errorMessage: 'permission-denied',
              onRetry: () => retryCount++,
            ),
          ),
        ),
      );

      expect(find.text('Tải tệp lên thất bại'), findsOneWidget);
      expect(find.text('permission-denied'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retryCount, 1);
    });

    testWidgets('CloudSyncBadge renders proper badges for cloud and web URLs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CloudSyncBadge(fileUrl: 'firebase-storage://users/1/doc/a.pdf'),
                CloudSyncBadge(fileUrl: 'https://example.com/slide.pdf'),
                CloudSyncBadge(fileUrl: 'local_file.pdf'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Cloud Storage'), findsOneWidget);
      expect(find.text('Liên kết Web'), findsOneWidget);
      expect(find.text('Tệp đính kèm'), findsOneWidget);
    });
  });
}
