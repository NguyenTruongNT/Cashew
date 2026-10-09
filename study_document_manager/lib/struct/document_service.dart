import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../database/databaseGlobal.dart';
import 'checksum_utils.dart';
import 'firebase_storage_service.dart';
import 'google_auth_service.dart';
import 'models/document_models.dart';
import 'models/sync_models.dart';
import 'sync/sync_global.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG NGHIỆP VỤ: DỊCH VỤ XỬ LÝ LOGIC (DOCUMENT SERVICE)]
// File: lib/struct/document_service.dart
// Mô tả: Đóng gói toàn bộ Business Logic của hệ thống: kiểm tra tính hợp lệ
// của dữ liệu (Validation), phân loại, lọc, sắp xếp và tính toán thống kê.
// Tầng này đứng độc lập giữa Presentation Layer và Data Access Layer.
// =====================================================================

/// Đối tượng chứa thông tin thống kê tổng quan
class DocumentStats {
  final int totalDocuments;
  final int lectureCount;
  final int assignmentCount;
  final int referenceCount;
  final int examCount;
  final int pendingAssignments;
  final int completedAssignments;
  final int favoriteCount;

  DocumentStats({
    required this.totalDocuments,
    required this.lectureCount,
    required this.assignmentCount,
    required this.referenceCount,
    required this.examCount,
    required this.pendingAssignments,
    required this.completedAssignments,
    required this.favoriteCount,
  });

  factory DocumentStats.fromList(List<DocumentModel> list) {
    int lectures = 0;
    int assignments = 0;
    int references = 0;
    int exams = 0;
    int pending = 0;
    int completed = 0;
    int favorites = 0;

    for (final doc in list) {
      if (doc.isFavorite) favorites++;

      switch (doc.type) {
        case DocumentType.lecture:
          lectures++;
          break;
        case DocumentType.assignment:
          assignments++;
          if (doc.status == DocumentStatus.completed) {
            completed++;
          } else {
            pending++;
          }
          break;
        case DocumentType.reference:
          references++;
          break;
        case DocumentType.exam:
          exams++;
          break;
      }
    }

    return DocumentStats(
      totalDocuments: list.length,
      lectureCount: lectures,
      assignmentCount: assignments,
      referenceCount: references,
      examCount: exams,
      pendingAssignments: pending,
      completedAssignments: completed,
      favoriteCount: favorites,
    );
  }
}

/// Tiêu chí sắp xếp danh sách tài liệu
enum DocumentSortOption {
  latestUpdated,
  titleAsc,
  deadlineEarliest,
  priorityHighest,
}

class DocumentService {
  // ===================================================================
  // 1. KIỂM THỰC DỮ LIỆU (VALIDATION LOGIC)
  // ===================================================================

  /// Kiểm tra tiêu đề tài liệu
  static String? validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'Tiêu đề tài liệu không được để trống';
    }
    if (title.trim().length < 3) {
      return 'Tiêu đề tài liệu phải có ít nhất 3 ký tự';
    }
    if (title.length > 250) {
      return 'Tiêu đề không được vượt quá 250 ký tự';
    }
    return null;
  }

  /// Kiểm tra đường dẫn URL hoặc File
  static String? validateUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null; // Được phép để trống
    }
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null &&
        uri.scheme == 'firebase-storage' &&
        uri.path.isNotEmpty) {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (uri == null || !uri.hasAuthority) {
        return 'Định dạng đường dẫn liên kết URL không hợp lệ';
      }
    }
    return null;
  }

  /// Kiểm tra hạn nộp của bài tập
  static String? validateDeadline(DateTime? deadline, DocumentType type) {
    if (type == DocumentType.assignment && deadline == null) {
      // Đối với bài tập, có thể khuyến nghị hoặc bắt buộc
      return null;
    }
    return null;
  }

  // ===================================================================
  // 2. NGHIỆP VỤ LỌC & SẮP XẾP (FILTERING & SORTING LOGIC)
  // ===================================================================

  /// Lọc và sắp xếp danh sách tài liệu trong bộ nhớ (In-memory filter)
  static List<DocumentModel> filterAndSort({
    required List<DocumentModel> source,
    String? searchQuery,
    DocumentType? typeFilter,
    String? subjectIdFilter,
    bool? onlyFavorites,
    DocumentSortOption sortOption = DocumentSortOption.latestUpdated,
  }) {
    var result = List<DocumentModel>.from(source);

    // Lọc theo từ khóa tìm kiếm
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      result = result.where((doc) {
        final matchTitle = doc.title.toLowerCase().contains(query);
        final matchNotes = doc.notes.toLowerCase().contains(query);
        final matchTags = doc.tags.any((tag) => tag.toLowerCase().contains(query));
        return matchTitle || matchNotes || matchTags;
      }).toList();
    }

    // Lọc theo loại tài liệu
    if (typeFilter != null) {
      result = result.where((doc) => doc.type == typeFilter).toList();
    }

    // Lọc theo môn học
    if (subjectIdFilter != null && subjectIdFilter.isNotEmpty) {
      result = result.where((doc) => doc.subjectId == subjectIdFilter).toList();
    }

    // Lọc yêu thích
    if (onlyFavorites == true) {
      result = result.where((doc) => doc.isFavorite).toList();
    }

    // Sắp xếp
    switch (sortOption) {
      case DocumentSortOption.latestUpdated:
        result.sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
        break;
      case DocumentSortOption.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case DocumentSortOption.deadlineEarliest:
        result.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        break;
      case DocumentSortOption.priorityHighest:
        result.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;
    }

    return result;
  }

  // ===================================================================
  // 3. ĐIỀU PHỐI THAO TÁC CƠ SỞ DỮ LIỆU (DATABASE ORCHESTRATION)
  // Chiến lược Offline-First: ghi cục bộ ngay + đưa vào outbox để đồng bộ.
  // ===================================================================

  /// Xử lý tệp đính kèm: tính checksum và cache cục bộ (nếu bật đồng bộ).
  static Future<DocumentModel> _attachFileIfAny(
    DocumentModel document, {
    List<int>? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes == null || fileBytes.isEmpty) return document;

    final checksum = ChecksumUtils.computeResult(
      fileBytes,
      algorithm: ChecksumUtils.defaultAlgorithm,
    );
    var result = document.copyWith(
      checksum: checksum.value,
      checksumAlgorithm: checksum.algorithm.nameString,
      updatedDate: document.updatedDate,
    );

    if (syncEngine != null) {
      final path = await syncEngine!.fileStore.save(
        fileName ?? '${document.id}.bin',
        fileBytes,
      );
      result = result.copyWith(localPath: path, updatedDate: result.updatedDate);
    }
    return result;
  }

  /// Tạo mới tài liệu có kiểm tra tính hợp lệ (Offline-First).
  static Future<void> saveDocument(
    DocumentModel document, {
    List<int>? fileBytes,
    String? fileName,
    bool fileAlreadyUploaded = false,
  }) async {
    final titleError = validateTitle(document.title);
    if (titleError != null) {
      throw ArgumentError(titleError);
    }
    final urlError = validateUrl(document.fileUrl);
    if (urlError != null) {
      throw ArgumentError(urlError);
    }

    var doc = await _attachFileIfAny(
      document,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    doc = doc.copyWith(
      syncStatus: isSyncEnabled ? SyncStatus.pendingUpload : SyncStatus.localOnly,
      updatedDate: doc.updatedDate,
    );
    await database.insertDocument(doc);
    await _enqueueAndSync(
      doc.id,
      SyncOperation.upsert,
      payload: {'file_uploaded': fileAlreadyUploaded},
    );
  }

  /// Cập nhật tài liệu (Offline-First, tăng version để phát hiện xung đột).
  static Future<void> updateDocument(
    DocumentModel document, {
    List<int>? fileBytes,
    String? fileName,
    bool fileAlreadyUploaded = false,
  }) async {
    final titleError = validateTitle(document.title);
    if (titleError != null) {
      throw ArgumentError(titleError);
    }

    var doc = document.copyWith(
      updatedDate: DateTime.now(),
      version: document.version + 1,
    );
    doc = await _attachFileIfAny(doc, fileBytes: fileBytes, fileName: fileName);
    doc = doc.copyWith(
      syncStatus: isSyncEnabled ? SyncStatus.pendingUpload : doc.syncStatus,
      updatedDate: doc.updatedDate,
    );
    await database.updateDocument(doc);
    await _enqueueAndSync(
      doc.id,
      SyncOperation.upsert,
      payload: {'file_uploaded': fileAlreadyUploaded},
    );
  }

  /// Xóa tài liệu theo cơ chế tombstone: ghi `delete_logs` + outbox,
  /// sau đó xóa cục bộ. Cloud sẽ được đồng bộ khi có mạng.
  static Future<void> deleteDocument(String id) async {
    final document = await database.getDocumentById(id);
    final storagePath = document?.storagePath;
    final deleteLogId = const Uuid().v4();

    await database.insertDeleteLog(
      DeleteLogModel(
        id: deleteLogId,
        documentId: id,
        ownerId: syncEngine?.ownerId,
        storagePath: storagePath,
        checksum: document?.checksum,
        deletedAt: DateTime.now(),
        source: 'local',
        syncStatus: DeleteLogStatus.pending,
      ),
    );

    if (document?.localPath case final localPath?) {
      if (syncEngine != null) {
        await syncEngine!.fileStore.delete(localPath);
      }
    }

    await database.deleteDocument(id);

    // Dọn tệp trên Firebase Storage (nếu đang đăng nhập) để tránh tệp mồ côi.
    if (storagePath != null && _firebaseReady) {
      try {
        await FirebaseStorageService.instance.delete(storagePath);
      } catch (_) {
        // Bỏ qua: tệp sẽ được đối soát lại khi đồng bộ.
      }
    }

    if (isSyncEnabled) {
      await database.enqueueOutbox(
        entityId: id,
        operation: SyncOperation.delete,
        payload: {
          'delete_log_id': deleteLogId,
          'storage_path': storagePath,
        },
      );
      unawaited(syncEngine!.syncNow());
    }
  }

  /// Đưa thao tác vào outbox và kích hoạt đồng bộ nền (nếu đã bật).
  static Future<void> _enqueueAndSync(
    String documentId,
    SyncOperation operation, {
    Map<String, dynamic>? payload,
  }) async {
    if (!isSyncEnabled) return;
    await database.enqueueOutbox(
      entityId: documentId,
      operation: operation,
      payload: payload,
    );
    unawaited(syncEngine!.syncNow());
  }

  static bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty &&
          GoogleAuthService.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Bật/Tắt trạng thái yêu thích
  static Future<void> toggleFavorite(DocumentModel doc) async {
    final updated = doc.copyWith(isFavorite: !doc.isFavorite);
    await database.updateDocument(updated);
  }

  /// Đổi trạng thái xử lý bài tập (Hoàn thành / Chưa làm)
  static Future<void> toggleStatus(DocumentModel doc) async {
    final newStatus = doc.status == DocumentStatus.completed
        ? DocumentStatus.inProgress
        : DocumentStatus.completed;
    final updated = doc.copyWith(status: newStatus);
    await database.updateDocument(updated);
  }
}
