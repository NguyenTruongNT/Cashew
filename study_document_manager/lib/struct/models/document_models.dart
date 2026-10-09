import 'package:flutter/material.dart';
import '../../colors.dart';

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

/// Trạng thái đồng bộ của tài liệu với Cloud (Offline-First)
enum SyncStatus {
  /// Chỉ tồn tại cục bộ, chưa từng/không đồng bộ Cloud.
  localOnly,

  /// Có thay đổi cục bộ đang chờ đẩy lên Cloud.
  pendingUpload,

  /// Đã xóa cục bộ, đang chờ đẩy thao tác xóa lên Cloud.
  pendingDelete,

  /// Dữ liệu cục bộ và Cloud đã đồng bộ (khớp checksum/version).
  synced,

  /// Phát hiện xung đột phiên bản giữa cục bộ và Cloud cần xử lý.
  conflict,
}

extension SyncStatusExtension on SyncStatus {
  String get nameString {
    switch (this) {
      case SyncStatus.localOnly:
        return 'localOnly';
      case SyncStatus.pendingUpload:
        return 'pendingUpload';
      case SyncStatus.pendingDelete:
        return 'pendingDelete';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.conflict:
        return 'conflict';
    }
  }

  String get displayName {
    switch (this) {
      case SyncStatus.localOnly:
        return 'Cục bộ';
      case SyncStatus.pendingUpload:
        return 'Chờ tải lên';
      case SyncStatus.pendingDelete:
        return 'Chờ xóa';
      case SyncStatus.synced:
        return 'Đã đồng bộ';
      case SyncStatus.conflict:
        return 'Xung đột';
    }
  }

  static SyncStatus fromString(String? val) {
    switch (val) {
      case 'synced':
        return SyncStatus.synced;
      case 'pendingUpload':
        return SyncStatus.pendingUpload;
      case 'pendingDelete':
        return SyncStatus.pendingDelete;
      case 'conflict':
        return SyncStatus.conflict;
      case 'localOnly':
      default:
        return SyncStatus.localOnly;
    }
  }
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
  final String? storagePath;
  final List<String> tags;
  final DocumentStatus status;
  final PriorityLevel priority;
  final bool isFavorite;
  final DateTime? deadline;
  final DateTime createdDate;
  final DateTime updatedDate;

  // -------- Trường phục vụ đồng bộ Offline-First (schema v3) --------
  /// Checksum MD5/SHA-256 của tệp đính kèm (kiểm tra tính toàn vẹn).
  final String? checksum;

  /// Thuật toán checksum đang dùng: 'md5' hoặc 'sha256'.
  final String checksumAlgorithm;

  /// Số phiên bản, tăng mỗi lần chỉnh sửa để phát hiện xung đột.
  final int version;

  /// Trạng thái đồng bộ với Cloud.
  final SyncStatus syncStatus;

  /// Đánh dấu xóa mềm cục bộ (tombstone).
  final bool isDeleted;

  /// Đường dẫn tệp cache cục bộ dùng khi Offline.
  final String? localPath;

  /// Thời điểm tài liệu được cập nhật trên Cloud.
  final DateTime? remoteUpdatedAt;

  /// Lần đồng bộ thành công gần nhất với Cloud.
  final DateTime? lastSyncedAt;

  DocumentModel({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.type,
    this.notes = '',
    this.fileUrl = '',
    this.storagePath,
    this.tags = const [],
    this.status = DocumentStatus.pending,
    this.priority = PriorityLevel.medium,
    this.isFavorite = false,
    this.deadline,
    required this.createdDate,
    required this.updatedDate,
    this.checksum,
    this.checksumAlgorithm = 'sha256',
    this.version = 1,
    this.syncStatus = SyncStatus.localOnly,
    this.isDeleted = false,
    this.localPath,
    this.remoteUpdatedAt,
    this.lastSyncedAt,
  });

  /// Chuyển đổi sang Map để lưu trữ trong SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject_id': subjectId,
      'type': type.nameString,
      'notes': notes,
      'file_url': fileUrl,
      'storage_path': storagePath,
      'tags': tags.join(','),
      'status': status.nameString,
      'priority': priority.index,
      'is_favorite': isFavorite ? 1 : 0,
      'deadline': deadline?.millisecondsSinceEpoch,
      'created_date': createdDate.millisecondsSinceEpoch,
      'updated_date': updatedDate.millisecondsSinceEpoch,
      'checksum': checksum,
      'checksum_algo': checksumAlgorithm,
      'version': version,
      'sync_status': syncStatus.nameString,
      'is_deleted': isDeleted ? 1 : 0,
      'local_path': localPath,
      'remote_updated_at': remoteUpdatedAt?.millisecondsSinceEpoch,
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
      storagePath: map['storage_path'] as String?,
      tags: parsedTags,
      status: DocumentStatusExtension.fromString(map['status'] as String?),
      priority: PriorityLevel.values[(map['priority'] as int? ?? 1).clamp(0, 2)],
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      deadline: map['deadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
          : null,
      createdDate: DateTime.fromMillisecondsSinceEpoch(map['created_date'] as int),
      updatedDate: DateTime.fromMillisecondsSinceEpoch(map['updated_date'] as int),
      checksum: map['checksum'] as String?,
      checksumAlgorithm: map['checksum_algo'] as String? ?? 'sha256',
      version: (map['version'] as int?) ?? 1,
      syncStatus: SyncStatusExtension.fromString(map['sync_status'] as String?),
      isDeleted: ((map['is_deleted'] as int?) ?? 0) == 1,
      localPath: map['local_path'] as String?,
      remoteUpdatedAt: map['remote_updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['remote_updated_at'] as int)
          : null,
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
    String? storagePath,
    List<String>? tags,
    DocumentStatus? status,
    PriorityLevel? priority,
    bool? isFavorite,
    DateTime? deadline,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? checksum,
    String? checksumAlgorithm,
    int? version,
    SyncStatus? syncStatus,
    bool? isDeleted,
    String? localPath,
    DateTime? remoteUpdatedAt,
    DateTime? lastSyncedAt,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      fileUrl: fileUrl ?? this.fileUrl,
      storagePath: storagePath ?? this.storagePath,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      isFavorite: isFavorite ?? this.isFavorite,
      deadline: deadline ?? this.deadline,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? DateTime.now(),
      checksum: checksum ?? this.checksum,
      checksumAlgorithm: checksumAlgorithm ?? this.checksumAlgorithm,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      localPath: localPath ?? this.localPath,
      remoteUpdatedAt: remoteUpdatedAt ?? this.remoteUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
