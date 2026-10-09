// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: KHAI BÁO & KẾT NỐI SYNC (BOOTSTRAP)]
// File: lib/struct/sync/sync_bootstrap.dart
// Mô tả: Điểm kết nối dịch vụ đồng bộ với ứng dụng:
//  - Nếu truyền backendOverride (test/demo) -> dùng backend đó.
//  - Nếu chạy trên nền tảng Firebase hỗ trợ (Web/Android/iOS) -> khởi tạo
//    FirebaseSyncBackend thật. Khi chưa có cấu hình/credentials, trả về null
//    (ứng dụng vẫn hoạt động bình thường, offline-first).
//  - Desktop/CI chưa cấu hình Firebase -> trả về null, không làm vỡ app.
// =====================================================================

import 'package:firebase_core/firebase_core.dart' show Firebase, FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../database/app_database.dart';
import 'connectivity_monitor.dart';
import 'file_cache_store.dart';
import 'firebase_sync_backend.dart';
import 'offline_sync_service.dart';
import 'sync_backend.dart';

/// Khởi tạo [OfflineSyncService] cho ứng dụng.
///
/// Trả về null khi nền tảng/credentials chưa sẵn sàng (không phải lỗi chí mạng).
Future<OfflineSyncService?> initCloudSyncService({
  required AppDatabase db,
  FirebaseOptions? options,
  SyncBackend? backendOverride,
  String deviceId = 'local-device',
}) async {
  final cacheRoot = await _defaultCacheRoot();

  // (1) Backend tùy chỉnh (dùng trong test/demo): dùng thẳng.
  if (backendOverride != null) {
    return OfflineSyncService(
      db: db,
      backend: backendOverride,
      connectivity: ManualConnectivityMonitor(),
      fileCache: createFileCacheStore(cacheRoot),
      deviceId: deviceId,
    );
  }

  // (2) Firebase thật: chỉ hỗ trợ Web / Android / iOS.
  final supported = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!supported) {
    debugPrint('[CloudSync] Nền tảng này chưa cấu hình Firebase - bỏ qua Cloud Sync.');
    return null;
  }

  try {
    if (Firebase.apps.isEmpty) {
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        // Trên Web cần options; nếu thiếu sẽ ném lỗi -> bị bắt ở dưới.
        await Firebase.initializeApp();
      }
    }
    final service = OfflineSyncService(
      db: db,
      backend: FirebaseSyncBackend.defaults(),
      connectivity: ManualConnectivityMonitor(),
      fileCache: createFileCacheStore(cacheRoot),
      deviceId: deviceId,
    );
    debugPrint('[CloudSync] Đã kết nối Firebase - Offline Sync sẵn sàng.');
    return service;
  } catch (e) {
    debugPrint('[CloudSync] Không khởi tạo được Firebase, chạy Offline-First: $e');
    return null;
  }
}

/// Thư mục gốc cho Local Cache (ưu tiên Documents dir, fallback trong app).
Future<String> _defaultCacheRoot() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'doc_file_cache');
  } catch (_) {
    return 'doc_file_cache';
  }
}