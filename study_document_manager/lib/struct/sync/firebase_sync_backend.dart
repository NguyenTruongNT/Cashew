// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: CLOUD BACKEND FIREBASE (THẬT)]
// File: lib/struct/sync/firebase_sync_backend.dart
// Mô tả: Bản cài đặt SyncBackend bằng Firebase thật:
//  - Cloud Firestore : metadata tài liệu + tombstone xóa (delete_logs).
//  - Firebase Storage : nội dung byte tệp, xác thực bằng checksum.
//  - Firebase Auth    : phân tách dữ liệu theo UID người dùng.
//
// Cấu trúc dữ liệu (per user):
//   users/{uid}/documents/{documentId}    -> RemoteDocument.toCloudMap()
//   users/{uid}/deleteLogs/{documentId_ts}-> tombstone xóa
//   users/{uid}/files/{documentId}        -> byte tệp (Firebase Storage)
//
// LƯU Ý deployment: bộ lọc "updated_date" + "orderBy" cần composite index
// trong Firestore; để đồng bộ chạy tốt hãy đặt rule ghi/xóa trước.
// =====================================================================

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'checksum_util.dart';
import 'sync_backend.dart';
import 'sync_models.dart';

/// Mã lỗi Firebase được coi là lỗi mạng thoáng qua (kích hoạt retry).
const Set<String> _transientFirebaseCodes = {
  'unavailable',
  'deadline-exceeded',
  'network-error',
  'resource-exhausted',
  'aborted',
  'internal',
};

/// Backend đồng bộ thật với Firebase.
class FirebaseSyncBackend implements SyncBackend {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final FirebaseAuth auth;

  /// Ghi đè UID nếu không muốn phụ thuộc phiên đăng nhập hiện tại.
  final String? overrideUserId;

  FirebaseSyncBackend({
    required this.firestore,
    required this.storage,
    required this.auth,
    this.overrideUserId,
  });

  /// Tạo backend với các instance Firebase mặc định (sau Firebase.initializeApp).
  factory FirebaseSyncBackend.defaults({String? overrideUserId}) {
    return FirebaseSyncBackend(
      firestore: FirebaseFirestore.instance,
      storage: FirebaseStorage.instance,
      auth: FirebaseAuth.instance,
      overrideUserId: overrideUserId,
    );
  }

  /// UID người dùng hiện tại (fallback 'anonymous' khi chưa đăng nhập).
  String get _uid => overrideUserId ?? auth.currentUser?.uid ?? 'anonymous';

  CollectionReference<Map<String, dynamic>> get _documentsRef =>
      firestore.collection('users').doc(_uid).collection('documents');

  CollectionReference<Map<String, dynamic>> get _deleteLogsRef =>
      firestore.collection('users').doc(_uid).collection('deleteLogs');

  /// Thư mục tệp của người dùng trên Firebase Storage.
  String get _filesRootPath => 'users/$_uid/files';

  Reference get _bucketRef => storage.ref(_filesRootPath);

  // ================================================================
  // METADATA TÀI LIỆU
  // ================================================================

  @override
  Future<List<RemoteDocument>> pullDocuments({DateTime? since}) async {
    return _withNetworkGuard(() async {
      Query<Map<String, dynamic>> query =
          _documentsRef.where('deleted', isEqualTo: false);
      if (since != null) {
        query = query
            .where('updated_date', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('updated_date')
            .limit(500);
      } else {
        query = query.orderBy('updated_date').limit(500);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => RemoteDocument.fromMap(_normalizeDates(doc.data())))
          .toList();
    });
  }

  @override
  Future<RemoteDocument> upsertDocument(RemoteDocument document) async {
    return _withNetworkGuard(() async {
      final data = _toFirestoreMap(document);
      await _documentsRef.doc(document.id).set(data);
      final version = DateTime.now().millisecondsSinceEpoch;
      return document.copyWith(remoteVersion: version);
    });
  }

  @override
  Future<void> deleteDocument(
    String documentId,
    DateTime deletedAt, {
    String? checksum,
  }) async {
    return _withNetworkGuard(() async {
      final logId = '${documentId}_${deletedAt.millisecondsSinceEpoch}';
      await _deleteLogsRef.doc(logId).set({
        'id': logId,
        'document_id': documentId,
        'deleted_at': Timestamp.fromDate(deletedAt),
        'device_id': 'cloud',
        'checksum': checksum,
      });
      // Xóa metadata, sau đó bỏ lỗi nếu tệp chưa tồn tại.
      await _documentsRef.doc(documentId).delete();
      try {
        await _bucketRef.child(documentId).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    });
  }

  @override
  Future<List<DeleteLogEntry>> pullDeletes({DateTime? since}) async {
    return _withNetworkGuard(() async {
      Query<Map<String, dynamic>> query = _deleteLogsRef;
      if (since != null) {
        query = query
            .where('deleted_at', isGreaterThan: Timestamp.fromDate(since))
            .orderBy('deleted_at')
            .limit(500);
      } else {
        query = query.orderBy('deleted_at').limit(500);
      }
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => DeleteLogEntry.fromMap(_normalizeDates(doc.data())))
          .toList();
    });
  }

  // ================================================================
  // NỘI DUNG TỆP (FIREBASE STORAGE)
  // ================================================================

  @override
  Future<void> uploadFile(String documentId, String checksum, List<int> bytes) async {
    return _withNetworkGuard(() async {
      final ref = _bucketRef.child(documentId);
      await ref.putData(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        SettableMetadata(
          contentType: 'application/octet-stream',
          customMetadata: {'checksum': checksum, 'algorithm': ChecksumAlgorithm.sha256.nameString},
        ),
      );
    });
  }

  @override
  Future<List<int>?> downloadFile(String documentId, String checksum) async {
    return _withNetworkGuard(() async {
      final ref = _bucketRef.child(documentId);
      final Uint8List? data;
      try {
        data = await ref.getData();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') return null;
        rethrow;
      }
      if (data == null) return null;
      // Kiểm tra tính toàn vẹn tệp trước khi trả về.
      if (!ChecksumUtil.matches(ChecksumUtil.sha256Hex(data), checksum)) {
        return null;
      }
      return data;
    });
  }

  @override
  Future<void> deleteFile(String documentId) async {
    return _withNetworkGuard(() async {
      try {
        await _bucketRef.child(documentId).delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    });
  }

  // ================================================================
  // TIỆN ÍCH CHUYỂN ĐỔI
  // ================================================================

  /// Map cho Firestore: ngày tháng -> Timestamp; loại bỏ trường nội bộ.
  Map<String, dynamic> _toFirestoreMap(RemoteDocument doc) {
    final map = doc.toCloudMap();
    if (map['deadline'] is int) {
      map['deadline'] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int));
    }
    if (map['created_date'] is int) {
      map['created_date'] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(map['created_date'] as int));
    }
    if (map['updated_date'] is int) {
      map['updated_date'] = Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(map['updated_date'] as int));
    }
    return map;
  }

  Map<String, dynamic> _normalizeDates(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    for (final key in ['deadline', 'created_date', 'updated_date', 'deleted_at', 'remote_purged_at']) {
      if (result[key] is Timestamp) {
        result[key] = (result[key] as Timestamp).toDate().millisecondsSinceEpoch;
      }
    }
    return result;
  }

  /// Bọc lỗi mạng thoáng qua để dịch vụ retry xử lý được.
  Future<T> _withNetworkGuard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (e) {
      if (_transientFirebaseCodes.contains(e.code)) {
        throw SyncNetworkException('Firebase $e.code: ${e.message}');
      }
      rethrow;
    }
  }
}