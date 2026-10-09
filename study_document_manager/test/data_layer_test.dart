import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/database/app_database.dart';
import 'package:study_document_manager/struct/models/document_models.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ TẦNG DỮ LIỆU (DATA LAYER TEST)]
// File: test/data_layer_test.dart
// Mô tả: Kiểm tra tính đúng đắn của các thao tác CRUD, tìm kiếm,
// và cơ chế phản ứng dữ liệu (Reactive Stream) trên SQLite.
// =====================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase();
    // Khởi tạo database in-memory để đảm bảo mỗi bài test độc lập và tốc độ cực nhanh
    await db.init(isInMemory: true);
  });

  tearDown(() async {
    await db.close();
  });

  group('Kiểm thử Tầng Dữ liệu (Data Layer - SQLite CRUD & Search)', () {
    test('1. Kiểm tra nạp dữ liệu mẫu ban đầu (Seeding Data)', () async {
      final subjects = await db.getAllSubjects();
      final docs = await db.getAllDocuments();

      expect(subjects.isNotEmpty, isTrue, reason: 'Phải có môn học mẫu ban đầu');
      expect(docs.isNotEmpty, isTrue, reason: 'Phải có tài liệu mẫu ban đầu');
    });

    test('2. Thêm mới tài liệu học tập (Insert / Create)', () async {
      final newDoc = DocumentModel(
        id: 'test_doc_101',
        title: 'Kiểm thử Đơn vị trong Kiến trúc Cashew',
        subjectId: 'sub_swe',
        type: DocumentType.lecture,
        notes: 'Ghi chú bài học kiểm thử',
        fileUrl: 'https://example.com/test.pdf',
        tags: ['UnitTest', 'Cashew'],
        status: DocumentStatus.pending,
        priority: PriorityLevel.high,
        isFavorite: true,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      final insertResult = await db.insertDocument(newDoc);
      expect(insertResult, greaterThan(0));

      final retrieved = await db.getDocumentById('test_doc_101');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Kiểm thử Đơn vị trong Kiến trúc Cashew'));
      expect(retrieved.tags, contains('UnitTest'));
      expect(retrieved.isFavorite, isTrue);
    });

    test('3. Chỉnh sửa thông tin tài liệu (Update)', () async {
      final docs = await db.getAllDocuments();
      final targetDoc = docs.first;

      final updatedDoc = targetDoc.copyWith(
        title: 'Tiêu đề đã được sửa thành công',
        status: DocumentStatus.completed,
      );

      await db.updateDocument(updatedDoc);

      final retrieved = await db.getDocumentById(targetDoc.id);
      expect(retrieved!.title, equals('Tiêu đề đã được sửa thành công'));
      expect(retrieved.status, equals(DocumentStatus.completed));
    });

    test('4. Xóa tài liệu học tập (Delete)', () async {
      final docs = await db.getAllDocuments();
      final targetDoc = docs.first;

      await db.deleteDocument(targetDoc.id);

      final retrieved = await db.getDocumentById(targetDoc.id);
      expect(retrieved, isNull, reason: 'Tài liệu sau khi xóa phải trả về null');
    });

    test('5. Tìm kiếm tài liệu theo từ khóa và bộ lọc (Search)', () async {
      // Tìm kiếm theo từ khóa có trong tiêu đề
      final searchByKeyword = await db.searchDocuments(query: 'Cashew');
      expect(
        searchByKeyword.first.title.contains('Cashew') ||
            searchByKeyword.first.tags.contains('Cashew') ||
            searchByKeyword.first.notes.contains('Cashew'),
        isTrue,
      );

      // Tìm kiếm theo loại tài liệu (Chỉ lấy bài tập)
      final searchByType = await db.searchDocuments(type: DocumentType.assignment);
      expect(searchByType.every((d) => d.type == DocumentType.assignment), isTrue);

      // Tìm kiếm theo môn học
      final searchBySubject = await db.searchDocuments(subjectId: 'sub_swe');
      expect(searchBySubject.every((d) => d.subjectId == 'sub_swe'), isTrue);
    });

    test('6. Kiểm tra luồng phản ứng dữ liệu (Reactive Stream watchAllDocuments)', () async {
      expectLater(
        db.watchAllDocuments,
        emits(isA<List<DocumentModel>>()),
      );

      // Thêm 1 tài liệu để kích hoạt Stream phát dữ liệu mới
      final testDoc = DocumentModel(
        id: 'reactive_doc_01',
        title: 'Tài liệu kích hoạt Reactive Stream',
        subjectId: 'sub_mob',
        type: DocumentType.reference,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      await db.insertDocument(testDoc);
    });
  });
}
