import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'database/app_database.dart';
import 'database/databaseGlobal.dart';
import 'firebase_options.dart';
import 'pages/auth_gate.dart';

// =====================================================================
// ĐIỂM KHỞI CHẠY ỨNG DỤNG QUẢN LÝ TÀI LIỆU
//
// - Khởi tạo Firebase.
// - Khởi tạo SQLite.
// - Theo dõi trạng thái đăng nhập.
// - Chuyển giữa LoginPage và HomePage.
// =====================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  database = AppDatabase();
  await database.init();

  runApp(const StudyDocumentApp());
}

class StudyDocumentApp extends StatelessWidget {
  const StudyDocumentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản Lý Tài Liệu Học Tập',
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
