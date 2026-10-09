import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/struct/document_service.dart';
import 'package:study_document_manager/struct/formatters.dart';
import 'package:study_document_manager/struct/models/document_models.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ TẦNG NGHIỆP VỤ (STRUCT LAYER TEST)]
// File: test/struct_layer_test.dart
// Mô tả: Kiểm tra tính đúng đắn của logic nghiệp vụ: Validation,
// tính toán thống kê (Statistics), và thuật toán lọc/sắp xếp độc lập với UI.
// =====================================================================

void main() {
  group('Kiểm thử Tầng Nghiệp vụ (Struct Layer - Validation & Business Logic)', () {
    test('1. Kiểm thực tiêu đề tài liệu (Validation Title)', () {
      expect(DocumentService.validateTitle(null), isNotNull);
      expect(DocumentService.validateTitle(''), isNotNull);
      expect(DocumentService.validateTitle('   '), isNotNull);
      expect(DocumentService.validateTitle('AB'), isNotNull, reason: 'Dưới 3 ký tự phải báo lỗi');
      expect(DocumentService.validateTitle('Slide Bài giảng 1'), isNull, reason: 'Tiêu đề hợp lệ');
    });

    test('2. Kiểm thực định dạng đường dẫn URL (Validation URL)', () {
      expect(DocumentService.validateUrl(''), isNull, reason: 'Cho phép để trống URL');
      expect(DocumentService.validateUrl('https://google.com/file.pdf'), isNull);
      expect(DocumentService.validateUrl('http://subdomain.example.edu.vn'), isNull);
    });

    test('3. Tính toán thống kê dữ liệu (Statistics Aggregation)', () {
      final now = DateTime.now();
      final sampleDocs = [
        DocumentModel(
          id: '1',
          title: 'Bài giảng 1',
          subjectId: 'sub1',
          type: DocumentType.lecture,
          createdDate: now,
          updatedDate: now,
        ),
        DocumentModel(
          id: '2',
          title: 'Bài tập 1',
          subjectId: 'sub1',
          type: DocumentType.assignment,
          status: DocumentStatus.pending,
          createdDate: now,
          updatedDate: now,
        ),
        DocumentModel(
          id: '3',
          title: 'Bài tập 2',
          subjectId: 'sub1',
          type: DocumentType.assignment,
          status: DocumentStatus.completed,
          createdDate: now,
          updatedDate: now,
        ),
        DocumentModel(
          id: '4',
          title: 'Tài liệu tham khảo',
          subjectId: 'sub2',
          type: DocumentType.reference,
          isFavorite: true,
          createdDate: now,
          updatedDate: now,
        ),
      ];

      final stats = DocumentStats.fromList(sampleDocs);
      expect(stats.totalDocuments, equals(4));
      expect(stats.lectureCount, equals(1));
      expect(stats.assignmentCount, equals(2));
      expect(stats.referenceCount, equals(1));
      expect(stats.pendingAssignments, equals(1));
      expect(stats.completedAssignments, equals(1));
      expect(stats.favoriteCount, equals(1));
    });

    test('4. Thuật toán Lọc và Sắp xếp trong bộ nhớ (In-memory Filtering & Sorting)', () {
      final now = DateTime.now();
      final docs = [
        DocumentModel(
          id: '1',
          title: 'Zebra Bài giảng',
          subjectId: 'sub1',
          type: DocumentType.lecture,
          notes: 'Mô tả A',
          tags: ['Toán'],
          createdDate: now,
          updatedDate: now.subtract(const Duration(hours: 3)),
        ),
        DocumentModel(
          id: '2',
          title: 'Alpha Bài tập',
          subjectId: 'sub2',
          type: DocumentType.assignment,
          notes: 'Mô tả B',
          tags: ['Lập trình'],
          createdDate: now,
          updatedDate: now.subtract(const Duration(hours: 1)),
        ),
      ];

      // Lọc theo tag
      final filteredByTag = DocumentService.filterAndSort(
        source: docs,
        searchQuery: 'Lập trình',
      );
      expect(filteredByTag.length, equals(1));
      expect(filteredByTag.first.id, equals('2'));

      // Sắp xếp theo tên A - Z
      final sortedByName = DocumentService.filterAndSort(
        source: docs,
        sortOption: DocumentSortOption.titleAsc,
      );
      expect(sortedByName.first.title, equals('Alpha Bài tập'));
    });

    test('5. Định dạng ngày tháng và thời hạn (Formatters)', () {
      final testDate = DateTime(2026, 10, 3, 14, 30);
      expect(DocumentFormatters.formatDate(testDate), equals('03/10/2026'));
      expect(DocumentFormatters.formatDateTime(testDate), equals('14:30 - 03/10/2026'));

      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      expect(DocumentFormatters.formatRemainingTime(pastDate), contains('Đã quá hạn'));
    });
  });
}
