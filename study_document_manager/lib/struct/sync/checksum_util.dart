// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: TIỆN ÍCH BĂM TỆP (CHECKSUM)]
// File: lib/struct/sync/checksum_util.dart
// Mô tả: Tính giá trị băm toàn vẹn tệp (MD5 / SHA-256) phục vụ kiểm tra
// tính toàn vẹn dữ liệu khi truyền tải giữa Local Cache và Cloud.
// Sử dụng package:crypto (thuần Dart, chạy được cả Web/Desktop).
// =====================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Thuật toán băm được hỗ trợ để kiểm tra toàn vẹn tệp.
enum ChecksumAlgorithm {
  md5,
  sha256,
}

extension ChecksumAlgorithmExtension on ChecksumAlgorithm {
  String get nameString {
    switch (this) {
      case ChecksumAlgorithm.md5:
        return 'md5';
      case ChecksumAlgorithm.sha256:
        return 'sha256';
    }
  }

  static ChecksumAlgorithm fromString(String? val) {
    switch (val) {
      case 'md5':
        return ChecksumAlgorithm.md5;
      case 'sha256':
      default:
        return ChecksumAlgorithm.sha256;
    }
  }
}

/// Bộ tiện ích tính checksum cho chuỗi byte / văn bản.
class ChecksumUtil {
  ChecksumUtil._();

  /// Băm mảng byte bằng thuật toán chỉ định, trả về chuỗi hex thường.
  static String compute(List<int> bytes, {ChecksumAlgorithm algorithm = ChecksumAlgorithm.sha256}) {
    final digest = _digest(bytes, algorithm);
    return digest.toString();
  }

  /// Băm MD5 (tương thích ETag đơn giản của S3/Firebase metadata).
  static String md5Hex(List<int> bytes) => md5.convert(bytes).toString();

  /// Băm SHA-256 (khuyến nghị, an toàn hơn MD5).
  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  /// Băm nội dung văn bản UTF-8.
  static String computeText(String text, {ChecksumAlgorithm algorithm = ChecksumAlgorithm.sha256}) {
    return compute(utf8.encode(text), algorithm: algorithm);
  }

  /// So sánh hai checksum theo kiểu không phân biệt hoa thường.
  static bool matches(String? a, String? b) {
    if (a == null || b == null) return a == b;
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  /// Kiểm tra toàn vẹn: checksum tính lại có khớp với checksum kỳ vọng không.
  static bool verify(
    List<int> bytes,
    String expectedChecksum, {
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.sha256,
  }) {
    return matches(compute(bytes, algorithm: algorithm), expectedChecksum);
  }

  static Digest _digest(List<int> bytes, ChecksumAlgorithm algorithm) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    switch (algorithm) {
      case ChecksumAlgorithm.md5:
        return md5.convert(data);
      case ChecksumAlgorithm.sha256:
        return sha256.convert(data);
    }
  }
}
