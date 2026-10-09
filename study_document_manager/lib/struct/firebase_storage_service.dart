import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

class FirebaseStorageService {
  FirebaseStorageService._();

  static final FirebaseStorageService instance = FirebaseStorageService._();
  static const int maxFileSizeBytes = 20 * 1024 * 1024;
  static const String _storageValuePrefix = 'firebase-storage://';
  static const String _localAttachmentScheme = 'local-attachment';

  static String valueForPath(String path) =>
      '$_storageValuePrefix${Uri.encodeComponent(path)}';

  static bool isStorageValue(String value) =>
      value.startsWith(_storageValuePrefix);

  static String? pathFromValue(String value) {
    if (!isStorageValue(value)) return null;
    return Uri.decodeComponent(value.substring(_storageValuePrefix.length));
  }

  static String fileNameFromPath(String value) {
    final storagePath = pathFromValue(value);
    if (storagePath != null) return storagePath.split('/').last;

    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.scheme == _localAttachmentScheme &&
        uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    final legacy = value.replaceFirst('local-attachment://', '');
    final match = RegExp(r'_(\d{2}_.+)$').firstMatch(legacy);
    return match?.group(1) ?? legacy.split('/').last;
  }

  static String saveLocalAttachment({
    required String documentId,
    required String fileName,
    required Uint8List bytes,
  }) {
    return Uri(
      scheme: _localAttachmentScheme,
      host: documentId,
      path: '/${Uri.encodeComponent(fileName)}',
      queryParameters: {'data': base64UrlEncode(bytes)},
    ).toString();
  }

  static LocalAttachmentData? decodeLocalAttachment(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != _localAttachmentScheme) return null;
    final encodedBytes = uri.queryParameters['data'];
    if (encodedBytes == null || uri.pathSegments.isEmpty) return null;
    try {
      return LocalAttachmentData(
        fileName: uri.pathSegments.last,
        bytes: Uint8List.fromList(base64Url.decode(encodedBytes)),
      );
    } on FormatException {
      return null;
    }
  }

  static const Map<String, String> _contentTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',

    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
  };

  Future<String> uploadDocument({
    required PlatformFile file,
    required String documentId,
    required void Function(double progress) onProgress,
  }) async {
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase chỉ được cấu hình trên Android và Web.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Đăng nhập Google trước khi tải tệp lên.');
    }
    final size = await file.length();
    if (size == null) {
      throw StateError('Không xác định được dung lượng tệp.');
    }
    if (size > maxFileSizeBytes) {
      throw StateError('Tệp vượt quá giới hạn 20 MB.');
    }
    final extension = (file.extension ?? '').toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) {
      throw StateError('Định dạng tệp .$extension chưa được hỗ trợ.');
    }

    final bytes = await file.readAsBytes();

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final reference = FirebaseStorage.instance.ref(
      'users/${user.uid}/documents/$documentId/${const Uuid().v4()}/$safeName',
    );
    final task = reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'ownerUid': user.uid, 'documentId': documentId},
      ),
    );

    final progressSubscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    try {
      await task;
    } finally {
      await progressSubscription.cancel();
    }
    return reference.fullPath;
  }

  Future<String> downloadUrl(String storagePath) {
    return FirebaseStorage.instance.ref(storagePath).getDownloadURL();
  }

  Future<void> delete(String storagePath) {
    return _deleteObject(storagePath);
  }

  Future<void> _deleteObject(String storagePath) async {
    try {
      await FirebaseStorage.instance.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}

class LocalAttachmentData {
  const LocalAttachmentData({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
