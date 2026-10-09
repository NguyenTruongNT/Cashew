// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG NGHIỆP VỤ: TIỆN ÍCH CHECKSUM TOÀN VẸN TỆP]
// File: lib/struct/checksum_utils.dart
// Mô tả: Tính và xác minh checksum MD5/SHA-256 cho tệp tài liệu, phục vụ
// kiểm tra tính toàn vẹn dữ liệu trước/sau khi truyền tải lên Cloud.
// =====================================================================

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Thuật toán checksum được hỗ trợ.
enum ChecksumAlgorithm {
  md5, // Nhanh, tương thích ETag của nhiều Object Storage
  sha256; // An toàn hơn, khuyến nghị cho kiểm tra toàn vẹn

  String get nameString => name;

  static ChecksumAlgorithm fromString(String? value) {
    return value == 'md5' ? ChecksumAlgorithm.md5 : ChecksumAlgorithm.sha256;
  }
}

/// Kết quả tính checksum của một tệp.
class ChecksumResult {
  final String value;
  final ChecksumAlgorithm algorithm;
  final int sizeInBytes;

  const ChecksumResult({
    required this.value,
    required this.algorithm,
    required this.sizeInBytes,
  });

  @override
  String toString() => '${algorithm.nameString}:$value ($sizeInBytes bytes)';
}

/// Tiện ích tính/xác minh checksum MD5 và SHA-256.
class ChecksumUtils {
  const ChecksumUtils._();

  /// Thuật toán mặc định cho toàn hệ thống (ưu tiên SHA-256).
  static ChecksumAlgorithm defaultAlgorithm = ChecksumAlgorithm.sha256;

  /// Tính checksum cho một mảng byte.
  static String compute(
    List<int> bytes, {
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.sha256,
  }) {
    final digest = algorithm == ChecksumAlgorithm.md5
        ? md5.convert(bytes)
        : sha256.convert(bytes);
    return digest.toString();
  }

  /// Tính checksum cho chuỗi văn bản (dùng kiểm tra metadata).
  static String computeString(
    String text, {
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.sha256,
  }) {
    return compute(utf8.encode(text), algorithm: algorithm);
  }

  /// Tính checksum kèm metadata (thuật toán + kích thước).
  static ChecksumResult computeResult(
    List<int> bytes, {
    ChecksumAlgorithm algorithm = ChecksumAlgorithm.sha256,
  }) {
    return ChecksumResult(
      value: compute(bytes, algorithm: algorithm),
      algorithm: algorithm,
      sizeInBytes: bytes.length,
    );
  }

  /// Xác minh dữ liệu có khớp với checksum mong đợi hay không.
  /// Hỗ trợ tự suy luận thuật toán dựa trên độ dài chuỗi hex
  /// (MD5 = 32 ký tự, SHA-256 = 64 ký tự).
  static bool verify(
    List<int> bytes,
    String expected, {
    ChecksumAlgorithm? algorithm,
  }) {
    if (expected.isEmpty) return false;
    final algo = algorithm ??
        (expected.length == 32 ? ChecksumAlgorithm.md5 : ChecksumAlgorithm.sha256);
    final actual = compute(bytes, algorithm: algo);
    return _constantTimeEquals(actual, expected.toLowerCase());
  }

  /// So sánh chuỗi theo thời gian hằng số (giảm rủi ro timing attack).
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
