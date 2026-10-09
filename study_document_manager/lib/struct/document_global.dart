import 'package:flutter/material.dart';
import 'models/document_models.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG NGHIỆP VỤ: TRẠNG THÁI TOÀN CỤC (GLOBAL STATE)]
// File: lib/struct/document_global.dart
// Mô tả: Quản lý trạng thái chia sẻ giữa các trang (Bộ lọc môn học hiện tại,
// loại tài liệu đang chọn, từ khóa tìm kiếm) bằng ValueNotifier.
// =====================================================================

class DocumentGlobalState {
  /// Bộ lọc môn học đang được chọn (null = Tất cả môn học)
  static final ValueNotifier<String?> selectedSubjectId = ValueNotifier<String?>(null);

  /// Bộ lọc loại tài liệu đang chọn (null = Tất cả loại)
  static final ValueNotifier<DocumentType?> selectedType = ValueNotifier<DocumentType?>(null);

  /// Chế độ chỉ xem tài liệu yêu thích
  static final ValueNotifier<bool> onlyFavorites = ValueNotifier<bool>(false);

  /// Đặt lại toàn bộ bộ lọc về mặc định
  static void resetFilters() {
    selectedSubjectId.value = null;
    selectedType.value = null;
    onlyFavorites.value = false;
  }
}
