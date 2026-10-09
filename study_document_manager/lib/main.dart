import 'package:flutter/material.dart';
import 'colors.dart';
import 'database/app_database.dart';
import 'database/databaseGlobal.dart';
import 'pages/home_page.dart';
import 'struct/sync/offline_sync_service.dart';
import 'struct/sync/sync_bootstrap.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - ĐIỂM KHỞI CHẠY ỨNG DỤNG (ENTRY POINT)]
// File: lib/main.dart
// Đề tài: TH1 - Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew
// Mô tả: Khởi tạo cơ sở dữ liệu SQLite, khởi tạo dịch vụ Cloud Sync
// (Offline-First Local Cache + Firebase), thiết lập giao diện Theme
// (Light/Dark), và khởi chạy màn hình chính HomePage.
// =====================================================================

/// Dịch vụ đồng bộ Cloud (null khi nền tảng chưa cấu hình Firebase).
OfflineSyncService? cloudSyncService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Database theo quy chuẩn Singleton của Cashew
  database = AppDatabase();
  await database.init();

  // Kết nối Cloud Sync (Firebase thật nếu có cấu hình; ngược lại chạy Offline-First).
  cloudSyncService = await initCloudSyncService(db: database);
  try {
    await cloudSyncService?.startAutoSync();
  } catch (e) {
    debugPrint('[Main] Không thể khởi động Cloud Sync: $e');
  }

  runApp(const StudyDocumentApp());
}

class StudyDocumentApp extends StatelessWidget {
  const StudyDocumentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Tài Liệu Học Tập (Kiến Trúc Cashew)',
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
