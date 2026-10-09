import 'dart:async';
import 'dart:convert';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

/// Bộ lưu trữ tệp đính kèm cục bộ (In-Memory Attachment Cache)
class AttachmentStore {
  AttachmentStore._();

  static final Map<String, Uint8List> _bytesStore = {};
  static final Map<String, String> _fileNameStore = {};

  static void put({
    required String key,
    required String fileName,
    required Uint8List bytes,
  }) {
    _bytesStore[key] = bytes;
    _fileNameStore[key] = fileName;
    final baseName = p.basename(fileName);
    _bytesStore[baseName] = bytes;
    _fileNameStore[baseName] = baseName;
  }

  static Uint8List? getBytes(String key) => _bytesStore[key];
  static String? getFileName(String key) => _fileNameStore[key];
  static bool has(String key) => _bytesStore.containsKey(key);

  static Uint8List? findBytes(String keyOrUrl) {
    if (_bytesStore.containsKey(keyOrUrl)) return _bytesStore[keyOrUrl];
    for (final entry in _bytesStore.entries) {
      if (entry.key.isNotEmpty &&
          (keyOrUrl.contains(entry.key) || entry.key.contains(keyOrUrl))) {
        return entry.value;
      }
    }
    return null;
  }

  static String? findFileName(String keyOrUrl) {
    if (_fileNameStore.containsKey(keyOrUrl)) return _fileNameStore[keyOrUrl];
    for (final entry in _fileNameStore.entries) {
      if (entry.key.isNotEmpty &&
          (keyOrUrl.contains(entry.key) || entry.key.contains(keyOrUrl))) {
        return entry.value;
      }
    }
    return null;
  }
}

class FirebaseUploadOperation {
  const FirebaseUploadOperation({
    required this.task,
    required this.storagePath,
  });

  final UploadTask task;
  final String storagePath;

  String get documentValue => FirebaseStorageService.valueForPath(storagePath);
}

class FirebaseStorageService {
  FirebaseStorageService._();

  static const int maxFileSizeBytes = 25 * 1024 * 1024;
  static const String _storageScheme = 'firebase-storage';
  static const String localAttachmentScheme = 'local-attachment';

  static const Map<String, String> _contentTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx':
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'txt': 'text/plain',
  };

  static bool isStorageValue(String value) =>
      value.startsWith('$_storageScheme:');

  static bool isLocalAttachment(String value) =>
      value.startsWith('$localAttachmentScheme://') ||
      value.startsWith('data:');

  /// Lưu tệp đính kèm cục bộ gọn nhẹ, trả về URI ngắn gọn không gây đơ ứng dụng
  static String saveLocalAttachment({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
  }) {
    final cleanFileName = p.basename(fileName);
    final key = 'att_${documentId}___$cleanFileName';
    AttachmentStore.put(key: key, fileName: cleanFileName, bytes: bytes);
    final encodedName = Uri.encodeComponent(cleanFileName);
    final encodedKey = Uri.encodeQueryComponent(key);
    return '$localAttachmentScheme://attachment/$encodedName?key=$encodedKey';
  }

  static String encodeLocalAttachment({
    required String fileName,
    required Uint8List bytes,
  }) {
    return saveLocalAttachment(
      documentId: 'local',
      fileName: fileName,
      bytes: bytes,
    );
  }

  static ({String fileName, Uint8List bytes})? decodeLocalAttachment(String value) {
    try {
      if (value.startsWith('$localAttachmentScheme://')) {
        final uri = Uri.parse(value);
        final keyFromQuery = uri.queryParameters['key'];
        final key = keyFromQuery ??
            (uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', ''));

        // 1. Kiểm tra trong AttachmentStore
        var bytes = AttachmentStore.getBytes(key) ??
            AttachmentStore.findBytes(key) ??
            AttachmentStore.findBytes(value);
        if (bytes != null) {
          final fileName = AttachmentStore.getFileName(key) ??
              AttachmentStore.findFileName(key) ??
              fileNameFromPath(value);
          return (fileName: fileName, bytes: bytes);
        }

        // 2. Tương thích ngược: Nếu có param ?data= (base64)
        final dataParam = uri.queryParameters['data'];
        if (dataParam != null) {
          final sanitizedData = dataParam.replaceAll(' ', '+');
          final decodedBytes = base64Decode(sanitizedData);
          final fileName = fileNameFromPath(value);
          AttachmentStore.put(key: key, fileName: fileName, bytes: decodedBytes);
          return (fileName: fileName, bytes: decodedBytes);
        }

        return null;
      } else if (value.startsWith('data:')) {
        final commaIndex = value.indexOf(',');
        if (commaIndex > 0) {
          final data = value.substring(commaIndex + 1).replaceAll(' ', '+');
          final bytes = base64Decode(data);
          final fileName = fileNameFromPath(value);
          return (fileName: fileName, bytes: bytes);
        }
      }
    } catch (e) {
      debugPrint('Lỗi giải mã tệp đính kèm cục bộ: $e');
    }
    return null;
  }

  static String? pathFromValue(String value) {
    if (!value.startsWith('$_storageScheme:')) return null;
    var path = value.substring('$_storageScheme:'.length);
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    return path.isEmpty ? null : path;
  }

  static String valueForPath(String path) {
    var cleanPath = path;
    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    return '$_storageScheme:///$cleanPath';
  }

  static String fileNameFromPath(String path) {
    if (path.isEmpty) return '';

    if (path.startsWith('$localAttachmentScheme://')) {
      final uri = Uri.tryParse(path);
      if (uri != null) {
        // 1. Kiểm tra path segments (định dạng mới: local-attachment://attachment/filename.pdf)
        if (uri.pathSegments.isNotEmpty) {
          final lastSegment = Uri.decodeComponent(uri.pathSegments.last);
          if (lastSegment.isNotEmpty &&
              lastSegment != 'attachment' &&
              lastSegment != 'local' &&
              lastSegment.contains('.')) {
            return lastSegment;
          }
        }

        // 2. Trích xuất key từ query hoặc host/path
        final keyFromQuery = uri.queryParameters['key'];
        final rawKey = keyFromQuery ??
            (uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', ''));

        // 3. Tra cứu trong AttachmentStore
        final cached = AttachmentStore.findFileName(rawKey) ??
            AttachmentStore.findFileName(path);
        if (cached != null && cached.isNotEmpty && cached.contains('.')) {
          return cached;
        }

        // 4. Phân tách bằng delimiter ___ nếu có (ví dụ: att_docId___fileName.pdf)
        if (rawKey.contains('___')) {
          final parts = rawKey.split('___');
          if (parts.length >= 2 && parts.last.isNotEmpty) {
            return Uri.decodeComponent(parts.last);
          }
        }

        // 5. Định dạng tương thích cũ (att_docId_fileName.ext)
        if (rawKey.startsWith('att_')) {
          var stripped = rawKey.substring(4);
          for (final prefix in ['assignment_', 'document_', 'exam_', 'local_']) {
            if (stripped.startsWith(prefix)) {
              stripped = stripped.substring(prefix.length);
              break;
            }
          }
          final firstUnderscore = stripped.indexOf('_');
          if (firstUnderscore != -1 && firstUnderscore < stripped.length - 1) {
            final possibleFileName = stripped.substring(firstUnderscore + 1);
            if (possibleFileName.contains('.')) {
              return Uri.decodeComponent(possibleFileName);
            }
          }
          if (stripped.contains('.')) {
            return Uri.decodeComponent(stripped);
          }
        }

        return Uri.decodeComponent(rawKey);
      }
    }

    final clean = path.split('?').first.split('#').first;
    return Uri.decodeComponent(p.basename(clean));
  }

  static FirebaseUploadOperation createUpload({
    required String userId,
    required String documentId,
    required String fileName,
    required Uint8List bytes,
  }) {
    if (bytes.lengthInBytes > maxFileSizeBytes) {
      throw FormatException('Kích thước tệp không được vượt quá 25 MB.');
    }

    final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) {
      throw FormatException('Định dạng tệp này chưa được hỗ trợ.');
    }

    final safeFileName = p
        .basename(fileName)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = 'users/$userId/documents/$documentId/$safeFileName';
    final task = FirebaseStorage.instance.ref(storagePath).putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return FirebaseUploadOperation(task: task, storagePath: storagePath);
  }

  static Future<String?> download({
    required String storagePath,
    required void Function(int transferredBytes, int? totalBytes) onProgress,
  }) async {
    final cleanPath = pathFromValue(storagePath) ?? storagePath;

    // 1. Nếu là Local Attachment: Giải mã và lưu tệp trực tiếp qua FileSaver
    if (isLocalAttachment(cleanPath)) {
      final decoded = decodeLocalAttachment(cleanPath);
      if (decoded != null) {
        onProgress(decoded.bytes.lengthInBytes, decoded.bytes.lengthInBytes);
        final extension = p.extension(decoded.fileName).replaceFirst('.', '').toLowerCase();
        final name = p.basenameWithoutExtension(decoded.fileName);
        return await FileSaver.instance.saveFile(
          name: name.isEmpty ? 'document' : name,
          bytes: decoded.bytes,
          fileExtension: extension.isEmpty ? 'bin' : extension,
          mimeType: MimeType.other,
        );
      }
      throw StateError('Không tìm thấy dữ liệu tệp đính kèm cục bộ.');
    }

    // 2. Nếu là Firebase Cloud Storage:
    final fileName = fileNameFromPath(cleanPath);
    final extension = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    final name = p.basenameWithoutExtension(fileName);

    try {
      final downloadUrl = await FirebaseStorage.instance
          .ref(cleanPath)
          .getDownloadURL();

      // Trên Web: Khởi chạy qua trình duyệt để tải tệp trực tiếp, không bị chặn bởi CORS
      if (kIsWeb) {
        onProgress(100, 100);
        await launchUrl(
          Uri.parse(downloadUrl),
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
        return downloadUrl;
      }

      // Trên Mobile / Desktop: Thử nạp bytes trực tiếp qua SDK
      try {
        final bytes = await FirebaseStorage.instance
            .ref(cleanPath)
            .getData(maxFileSizeBytes);
        if (bytes != null) {
          onProgress(bytes.lengthInBytes, bytes.lengthInBytes);
          return await FileSaver.instance.saveFile(
            name: name.isEmpty ? 'document' : name,
            bytes: bytes,
            fileExtension: extension,
            mimeType: MimeType.other,
          );
        }
      } catch (_) {
        // Fallback sang stream
      }

      final client = http.Client();
      try {
        final response = await client.send(
          http.Request('GET', Uri.parse(downloadUrl)),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.stream.drain<void>();
          throw StateError(
            'Không thể tải tệp từ Firebase Storage (HTTP ${response.statusCode}).',
          );
        }

        var transferredBytes = 0;
        final progressStream = response.stream.transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (chunk, sink) {
              transferredBytes += chunk.length;
              onProgress(transferredBytes, response.contentLength);
              sink.add(chunk);
            },
          ),
        );

        return await FileSaver.instance.saveAsStream(
          name: name.isEmpty ? 'document' : name,
          stream: progressStream,
          fileExtension: extension,
          mimeType: MimeType.other,
        );
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Lỗi tải tệp: $e');
      rethrow;
    }
  }
}
