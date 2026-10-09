import 'package:flutter/material.dart';
import 'colors.dart';
import 'database/app_database.dart';
import 'database/databaseGlobal.dart';
import 'pages/home_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - ĐIỂM KHỞI CHẠY ỨNG DỤNG (ENTRY POINT)]
// File: lib/main.dart
// Đề tài: TH1 - Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew
// Mô tả: Khởi tạo cơ sở dữ liệu SQLite, thiết lập giao diện Theme (Light/Dark),
// và khởi chạy màn hình chính HomePage.
// =====================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Database theo quy chuẩn Singleton của Cashew
  database = AppDatabase();
  await database.init();

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
