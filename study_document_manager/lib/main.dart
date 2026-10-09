import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'colors.dart';
import 'database/app_database.dart';
import 'database/databaseGlobal.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'struct/firebase_platform_support.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - ĐIỂM KHỞI CHẠY ỨNG DỤNG (ENTRY POINT)]
// File: lib/main.dart
// Đề tài: TH1 - Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew
// Mô tả: Khởi tạo cơ sở dữ liệu SQLite, thiết lập giao diện Theme (Light/Dark),
// và khởi chạy màn hình chính HomePage.
// =====================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  final firebaseSupported = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (firebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

  }

  // Khởi tạo Database theo quy chuẩn Singleton của Cashew
  database = AppDatabase();
  if (firebaseInitialized) {
    await database.setActiveOwner(FirebaseAuth.instance.currentUser?.uid);
  }
  await database.init();

  runApp(const StudyDocumentApp());
}

class StudyDocumentApp extends StatefulWidget {
  const StudyDocumentApp({super.key});

  @override
  State<StudyDocumentApp> createState() => _StudyDocumentAppState();
}

class _StudyDocumentAppState extends State<StudyDocumentApp> {
  StreamSubscription<User?>? _authOwnerSubscription;

  @override
  void initState() {
    super.initState();
    if (firebaseInitialized) {
      _authOwnerSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) => _updateOwner(user?.uid),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Không thể đọc trạng thái xác thực: $error');
        },
      );
    }
  }

  Future<void> _updateOwner(String? userId) async {
    try {
      await database.setActiveOwner(userId);
    } catch (error, stackTrace) {
      debugPrint(
        'Không thể cập nhật phạm vi dữ liệu theo tài khoản: $error\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    _authOwnerSubscription?.cancel();
    super.dispose();
  }

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
