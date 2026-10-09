import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_document_manager/struct/checksum_utils.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - KIỂM THỬ TẦNG NGHIỆP VỤ: CHECKSUM TOÀN VẸN TỆP]
// File: test/checksum_test.dart
// Mô tả: Kiểm chứng việc tính và xác minh checksum MD5/SHA-256 phục vụ
// kiểm tra tính toàn vẹn dữ liệu trong cơ chế Offline-First.
// =====================================================================

void main() {
  group('Kiểm thử Checksum (MD5 / SHA-256 Integrity)', () {
    test('1. Giá trị MD5 khớp vector chuẩn (Known Test Vectors)', () {
      expect(
        ChecksumUtils.compute([], algorithm: ChecksumAlgorithm.md5),
        equals('d41d8cd98f00b204e9800998ecf8427e'),
        reason: 'MD5 của chuỗi rỗng',
      );
      expect(
        ChecksumUtils.compute(
          utf8.encode('abc'),
          algorithm: ChecksumAlgorithm.md5,
        ),
        equals('900150983cd24fb0d6963f7d28e17f72'),
        reason: 'MD5 của "abc"',
      );
    });

    test('2. Giá trị SHA-256 khớp vector chuẩn (Known Test Vectors)', () {
      expect(
        ChecksumUtils.compute([], algorithm: ChecksumAlgorithm.sha256),
        equals(
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        ),
        reason: 'SHA-256 của chuỗi rỗng',
      );
      expect(
        ChecksumUtils.compute(
          utf8.encode('abc'),
          algorithm: ChecksumAlgorithm.sha256,
        ),
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
        reason: 'SHA-256 của "abc"',
      );
    });

    test('3. Thuật toán mặc định là SHA-256 và computeString hoạt động', () {
      expect(ChecksumUtils.defaultAlgorithm, equals(ChecksumAlgorithm.sha256));
      expect(
        ChecksumUtils.computeString('abc'),
        equals(
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
        ),
      );
    });

    test('4. computeResult trả về đúng thuật toán và kích thước', () {
      final result = ChecksumUtils.computeResult(
        utf8.encode('abc'),
        algorithm: ChecksumAlgorithm.md5,
      );
      expect(result.algorithm, equals(ChecksumAlgorithm.md5));
      expect(result.sizeInBytes, equals(3));
      expect(result.value, equals('900150983cd24fb0d6963f7d28e17f72'));
      expect(result.toString(), contains('md5:'));
    });

    test('5. verify xác minh đúng/sai và tự suy luận thuật toán', () {
      final data = utf8.encode('nội dung tài liệu thực hành');
      final md5Hex = ChecksumUtils.compute(data, algorithm: ChecksumAlgorithm.md5);
      final sha256Hex =
          ChecksumUtils.compute(data, algorithm: ChecksumAlgorithm.sha256);

      // Tự suy luận theo độ dài hex (MD5 = 32, SHA-256 = 64 ký tự).
      expect(ChecksumUtils.verify(data, md5Hex), isTrue);
      expect(ChecksumUtils.verify(data, sha256Hex), isTrue);

      // Chỉ định tường minh thuật toán.
      expect(
        ChecksumUtils.verify(data, md5Hex, algorithm: ChecksumAlgorithm.md5),
        isTrue,
      );

      // Dữ liệu bị hỏng hoặc checksum sai phải bị từ chối.
      expect(
        ChecksumUtils.verify(utf8.encode('nội dung khác'), sha256Hex),
        isFalse,
      );
      expect(ChecksumUtils.verify(data, ''), isFalse);
    });

    test('6. Checksum thay đổi khi dữ liệu thay đổi (phát hiện hỏng tệp)', () {
      final original = utf8.encode('ban dau');
      final tampered = utf8.encode('ban dau!');
      expect(
        ChecksumUtils.compute(original) == ChecksumUtils.compute(tampered),
        isFalse,
        reason: 'Chỉ thêm 1 byte cũng phải làm checksum thay đổi',
      );
    });
  });
}
