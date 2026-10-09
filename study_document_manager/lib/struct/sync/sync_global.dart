// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: BIẾN TOÀN CỤC SYNC ENGINE]
// File: lib/struct/sync/sync_global.dart
// Mô tả: Singleton toàn cục cho SyncEngine, tương tự `database` trong
// databaseGlobal.dart. Nullable để không phá vỡ các unit test không khởi
// tạo tầng đồng bộ.
// =====================================================================

import 'sync_engine.dart';

/// Bộ máy đồng bộ toàn cục (null nếu tầng đồng bộ chưa được khởi tạo).
SyncEngine? syncEngine;

/// Kiểm tra tầng đồng bộ đã sẵn sàng chưa.
bool get isSyncEnabled => syncEngine != null;
