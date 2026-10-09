import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/database/databaseGlobal.dart';
import 'package:study_document_manager/pages/add_edit_document_page.dart';
import 'package:study_document_manager/pages/home_page.dart';
import 'package:study_document_manager/struct/models/document_models.dart';
import 'package:study_document_manager/widgets/document_card.dart';
import 'package:study_document_manager/widgets/document_search_bar.dart';
import 'package:study_document_manager/widgets/filter_chip_bar.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ TẦNG GIAO DIỆN (PRESENTATION LAYER TEST)]
// File: test/presentation_layer_test.dart
// Mô tả: Kiểm tra tính đúng đắn của việc render widget, xử lý tương tác
// người dùng trên các thành phần giao diện tái sử dụng (UI Components).
// =====================================================================

void main() {
  group(
    'Kiểm thử Tầng Giao diện (Presentation Layer - Widgets & Interaction)',
    () {
      testWidgets('Có thể tạo tài liệu với môn học nhập tự do', (tester) async {
        database = AppDatabase();
        await tester.runAsync(() => database.init(isInMemory: true));
        addTearDown(() => tester.runAsync(() => database.close()));
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: AddEditDocumentPage()));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'HCI501 - Tương tác người máy',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'Bài tập thiết kế giao diện',
        );
        await tester.tap(find.text('Tạo mới'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();

        final subjects = await tester.runAsync(() => database.getAllSubjects());
        final documents = await tester.runAsync(
          () => database.searchDocuments(query: 'Bài tập thiết kế giao diện'),
        );
        final createdSubject = subjects!.singleWhere((s) => s.code == 'HCI501');

        expect(createdSubject.name, 'Tương tác người máy');
        expect(documents, hasLength(1));
        expect(documents!.single.subjectId, createdSubject.id);
        expect(tester.takeException(), isNull);

        await tester.runAsync(() => database.notifyDocumentsChanged());
        await tester.pumpWidget(const MaterialApp(home: HomePage()));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('1. Kiểm tra hiển thị thẻ tài liệu (DocumentCard Widget)', (
        tester,
      ) async {
        final doc = DocumentModel(
          id: 'ui_doc_1',
          title: 'Giáo trình Lập trình Flutter Cơ bản',
          subjectId: 'sub_mob',
          type: DocumentType.lecture,
          notes: 'Nội dung thực hành Flutter UI',
          tags: ['Flutter', 'Dart'],
          isFavorite: true,
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        );

        final subject = SubjectModel(
          id: 'sub_mob',
          name: 'Lập trình Thiết bị Di động',
          code: 'MOB401',
          colorValue: 0xFF43A047,
          iconName: 'phone',
          createdDate: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocumentCard(document: doc, subject: subject),
            ),
          ),
        );

        // Xác nhận tiêu đề và mã môn học được hiển thị
        expect(
          find.text('Giáo trình Lập trình Flutter Cơ bản'),
          findsOneWidget,
        );
        expect(find.text('MOB401'), findsOneWidget);
        expect(find.text('Bài giảng'), findsOneWidget);
        expect(
          find.byIcon(Icons.star_rounded),
          findsOneWidget,
        ); // Icon yêu thích
      });

      testWidgets(
        '2. Kiểm tra thanh lọc phân loại (FilterChipBar Interaction)',
        (tester) async {
          DocumentType? selected;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: FilterChipBar(
                  selectedType: null,
                  onSelected: (type) {
                    selected = type;
                  },
                ),
              ),
            ),
          );

          expect(find.text('Tất cả'), findsOneWidget);
          expect(find.text('Bài tập'), findsOneWidget);

          // Bấm vào chip 'Bài tập'
          await tester.tap(find.text('Bài tập'));
          await tester.pump();

          expect(selected, equals(DocumentType.assignment));
        },
      );

      testWidgets('3. Kiểm tra thanh tìm kiếm (DocumentSearchBar)', (
        tester,
      ) async {
        String searchKeyword = '';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocumentSearchBar(
                hintText: 'Tìm kiếm tài liệu...',
                onChanged: (val) {
                  searchKeyword = val;
                },
              ),
            ),
          ),
        );

        expect(find.text('Tìm kiếm tài liệu...'), findsOneWidget);

        // Nhập từ khóa tìm kiếm
        await tester.enterText(find.byType(TextField), 'Kiến trúc');
        // Đợi debounce 300ms
        await tester.pump(const Duration(milliseconds: 350));

        expect(searchKeyword, equals('Kiến trúc'));
      });
    },
  );
}
