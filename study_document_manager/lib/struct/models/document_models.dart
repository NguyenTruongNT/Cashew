import 'package:flutter/material.dart';
import '../../colors.dart';
import '../sync/sync_status.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG NGHIỆP VỤ: ĐỐI TƯỢNG VÀ MÔ HÌNH DỮ LIỆU (MODELS)]
// File: lib/struct/models/document_models.dart
// Mô tả: Định nghĩa các Enum phân loại và các Entity Model phản ánh
// chính xác dữ liệu trong ứng dụng Quản lý tài liệu học tập.
// =====================================================================

/// Phân loại tài liệu học tập
enum DocumentType {
  lecture,    // Bài giảng / Slide lý thuyết
  assignment, // Bài tập về nhà / Đồ án môn học
  reference,  // Tài liệu tham khảo / Sách / Giáo trình
  exam,       // Đề thi / Đề cương ôn tập
}

extension DocumentTypeExtension on DocumentType {
  String get nameString {
    switch (this) {
      case DocumentType.lecture:
        return 'lecture';
      case DocumentType.assignment:
        return 'assignment';
      case DocumentType.reference:
        return 'reference';
      case DocumentType.exam:
        return 'exam';
    }
  }

  String get displayName {
    switch (this) {
      case DocumentType.lecture:
        return 'Bài giảng';
      case DocumentType.assignment:
        return 'Bài tập';
      case DocumentType.reference:
        return 'Tham khảo';
      case DocumentType.exam:
        return 'Đề thi';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.lecture:
        return Icons.slideshow_rounded;
      case DocumentType.assignment:
        return Icons.assignment_outlined;
      case DocumentType.reference:
        return Icons.menu_book_rounded;
      case DocumentType.exam:
        return Icons.quiz_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DocumentType.lecture:
        return AppColors.lectureColor;   // Cyan — Bài giảng
      case DocumentType.assignment:
        return AppColors.assignmentColor; // Deep Orange — Bài tập
      case DocumentType.reference:
        return AppColors.referenceColor;  // Green — Tham khảo
      case DocumentType.exam:
        return AppColors.examColor;       // Purple — Đề thi
    }
  }

  static DocumentType fromString(String? val) {
    switch (val) {
      case 'assignment':
        return DocumentType.assignment;
      case 'reference':
        return DocumentType.reference;
      case 'exam':
        return DocumentType.exam;
      case 'lecture':
      default:
        return DocumentType.lecture;
    }
  }
}

/// Trạng thái xử lý tài liệu (đặc biệt hữu ích cho Bài tập / Đồ án)
enum DocumentStatus {
  pending,    // Chưa hoàn thành
  inProgress, // Đang thực hiện
  completed,  // Đã hoàn thành
}

extension DocumentStatusExtension on DocumentStatus {
  String get nameString {
    switch (this) {
      case DocumentStatus.pending:
        return 'pending';
      case DocumentStatus.inProgress:
        return 'inProgress';
      case DocumentStatus.completed:
        return 'completed';
    }
  }

  String get displayName {
    switch (this) {
      case DocumentStatus.pending:
        return 'Chưa làm';
      case DocumentStatus.inProgress:
        return 'Đang làm';
      case DocumentStatus.completed:
        return 'Hoàn thành';
    }
  }

  Color get color {
    switch (this) {
      case DocumentStatus.pending:
        return AppColors.statusPending;
      case DocumentStatus.inProgress:
        return AppColors.statusInProgress;
      case DocumentStatus.completed:
        return AppColors.statusCompleted;
    }
  }

  static DocumentStatus fromString(String? val) {
    switch (val) {
      case 'inProgress':
        return DocumentStatus.inProgress;
      case 'completed':
        return DocumentStatus.completed;
      case 'pending':
      default:
        return DocumentStatus.pending;
    }
  }
}

/// Mức độ ưu tiên
enum PriorityLevel {
  low,    // 0: Thấp
  medium, // 1: Trung bình
  high,   // 2: Cao / Quan trọng
}

/// Mô hình Môn học (Subject / Course)
class SubjectModel {
  final String id;
  final String name;
  final String code;
  final int colorValue;
  final String iconName;
  final DateTime createdDate;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.colorValue,
    required this.iconName,
    required this.createdDate,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'color': colorValue,
      'icon': iconName,
      'created_date': createdDate.millisecondsSinceEpoch,
    };
  }

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      colorValue: map['color'] as int,
      iconName: map['icon'] as String,
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['created_date'] as int),
    );
  }
}

/// Mô hình Tài liệu học tập (Document Model)
class DocumentModel {
  final String id;
  final String title;
  final String subjectId;
  final DocumentType type;
  final String notes;
  final String fileUrl;
  final List<String> tags;
  final DocumentStatus status;
  final PriorityLevel priority;
  final bool isFavorite;
  final DateTime? deadline;
  final DateTime createdDate;
  final DateTime updatedDate;

  // --- Trạng thái & metadata phục vụ Offline Sync ---
  /// Trạng thái đồng bộ so với Cloud (mặc định: đã đồng bộ).
  final SyncStatus syncStatus;

  /// Checksum MD5/SHA-256 của nội dung tệp đính kèm.
  final String? checksum;

  /// Kích thước tệp (byte).
  final int? fileSize;

  /// Đường dẫn tệp trong Local Cache (khi tải offline).
  final String? localFilePath;

  /// Phiên bản phía Cloud phục vụ giải quyết xung đột Last-Write-Wins.
  final int remoteVersion;

  /// Thời điểm đồng bộ gần nhất.
  final DateTime? lastSyncedAt;

  DocumentModel({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.type,
    this.notes = '',
    this.fileUrl = '',
    this.tags = const [],
    this.status = DocumentStatus.pending,
    this.priority = PriorityLevel.medium,
    this.isFavorite = false,
    this.deadline,
    required this.createdDate,
    required this.updatedDate,
    this.syncStatus = SyncStatus.synced,
    this.checksum,
    this.fileSize,
    this.localFilePath,
    this.remoteVersion = 0,
    this.lastSyncedAt,
  });

  /// Tài liệu đang có thay đổi cục bộ chờ đồng bộ lên Cloud hay không.
  bool get isPendingSync => syncStatus.isPending;

  /// Có tệp đính kèm đã được băm để kiểm tra toàn vẹn hay không.
  bool get hasChecksum => checksum != null && checksum!.isNotEmpty;

  /// Chuyển đổi sang Map để lưu trữ trong SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject_id': subjectId,
      'type': type.nameString,
      'notes': notes,
      'file_url': fileUrl,
      'tags': tags.join(','),
      'status': status.nameString,
      'priority': priority.index,
      'is_favorite': isFavorite ? 1 : 0,
      'deadline': deadline?.millisecondsSinceEpoch,
      'created_date': createdDate.millisecondsSinceEpoch,
      'updated_date': updatedDate.millisecondsSinceEpoch,
      'sync_status': syncStatus.nameString,
      'checksum': checksum,
      'file_size': fileSize,
      'local_file_path': localFilePath,
      'remote_version': remoteVersion,
      'last_synced_at': lastSyncedAt?.millisecondsSinceEpoch,
    };
  }

  /// Khởi tạo DocumentModel từ hàng dữ liệu SQLite
  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    final tagsStr = map['tags'] as String? ?? '';
    final List<String> parsedTags = tagsStr.isEmpty
        ? []
        : tagsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      subjectId: map['subject_id'] as String,
      type: DocumentTypeExtension.fromString(map['type'] as String?),
      notes: map['notes'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? '',
      tags: parsedTags,
      status: DocumentStatusExtension.fromString(map['status'] as String?),
      priority: PriorityLevel.values[(map['priority'] as int? ?? 1).clamp(0, 2)],
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      deadline: map['deadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
          : null,
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['created_date'] as int),
      updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updated_date'] as int),
      syncStatus: SyncStatusExtension.fromString(map['sync_status'] as String?),
      checksum: map['checksum'] as String?,
      fileSize: map['file_size'] as int?,
      localFilePath: map['local_file_path'] as String?,
      remoteVersion: map['remote_version'] as int? ?? 0,
      lastSyncedAt: map['last_synced_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_synced_at'] as int)
          : null,
    );
  }

  /// Tạo bản sao với các thuộc tính được cập nhật (Immutable State pattern)
  DocumentModel copyWith({
    String? id,
    String? title,
    String? subjectId,
    DocumentType? type,
    String? notes,
    String? fileUrl,
    List<String>? tags,
    DocumentStatus? status,
    PriorityLevel? priority,
    bool? isFavorite,
    DateTime? deadline,
    DateTime? createdDate,
    DateTime? updatedDate,
    SyncStatus? syncStatus,
    String? checksum,
    int? fileSize,
    String? localFilePath,
    int? remoteVersion,
    DateTime? lastSyncedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      fileUrl: fileUrl ?? this.fileUrl,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isFavorite: isFavorite ?? this.isFavorite,
      deadline: deadline ?? this.deadline,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
      checksum: checksum ?? this.checksum,
      fileSize: fileSize ?? this.fileSize,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  /// Sao chép chỉ các trường thuộc Offline Sync, **giữ nguyên** `updatedDate`.
  ///
  /// Khác với [copyWith] (luôn làm mới `updatedDate`), hàm này dùng cho các
  /// thao tác kỹ thuật (đánh dấu đã đồng bộ, ghi checksum...) không được phép
  /// làm sai lệch mốc thời gian Last-Write-Wins.
  DocumentModel copyWithSync({
    SyncStatus? syncStatus,
    String? checksum,
    int? fileSize,
    String? localFilePath,
    int? remoteVersion,
    DateTime? lastSyncedAt,
  }) {
    return DocumentModel(
      id: id,
      title: title,
      subjectId: subjectId,
      type: type,
      notes: notes,
      fileUrl: fileUrl,
      tags: tags,
      status: status,
      priority: priority,
      isFavorite: isFavorite,
      deadline: deadline,
      createdDate: createdDate,
      updatedDate: updatedDate,
      syncStatus: syncStatus ?? this.syncStatus,
      checksum: checksum ?? this.checksum,
      fileSize: fileSize ?? this.fileSize,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
