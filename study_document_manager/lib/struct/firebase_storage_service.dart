import 'dart:async';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';


class FirebaseStorageService {
  FirebaseStorageService._();


  static final FirebaseStorageService instance = FirebaseStorageService._();
  static const int maxFileSizeBytes = 20 * 1024 * 1024;


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
      throw StateError('Firebase chỉ được cấu hình trên Android, iOS và Web.');
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
    return FirebaseStorage.instance.ref(storagePath).delete();

  }
}
