import 'package:intl/intl.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG NGHIỆP VỤ: ĐỊNH DẠNG DỮ LIỆU (FORMATTERS)]
// File: lib/struct/formatters.dart
// Mô tả: Cung cấp các phương thức format ngày tháng, chuỗi ký tự,
// thời hạn deadline dành cho người dùng học sinh/sinh viên.
// =====================================================================

class DocumentFormatters {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('HH:mm - dd/MM/yyyy');

  /// Định dạng ngày: 03/10/2026
  static String formatDate(DateTime? date) {
    if (date == null) return 'Không có';
    return _dateFormat.format(date);
  }

  /// Định dạng ngày giờ: 14:30 - 03/10/2026
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Không có';
    return _dateTimeFormat.format(date);
  }

  /// Hiển thị thông báo thời hạn còn lại của bài tập
  static String formatRemainingTime(DateTime? deadline) {
    if (deadline == null) return 'Không có hạn nộp';
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      final days = difference.inDays.abs();
      return days == 0 ? 'Đã quá hạn hôm nay!' : 'Đã quá hạn $days ngày!';
    } else {
      if (difference.inDays > 0) {
        return 'Còn ${difference.inDays} ngày nữa';
      } else if (difference.inHours > 0) {
        return 'Còn ${difference.inHours} giờ nữa';
      } else {
        return 'Hạn chót sắp tới trong ${difference.inMinutes} phút!';
      }
    }
  }

  /// Cắt bớt văn bản nếu quá dài kèm dấu ba chấm
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
