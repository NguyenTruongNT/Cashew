import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';


import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';


import 'colors.dart';
import 'database/app_database.dart';
import 'database/databaseGlobal.dart';
import 'firebase_options.dart';

import 'pages/home_page.dart';
import 'struct/google_auth_service.dart';
import 'struct/sync/local_file_store_factory.dart';
import 'struct/sync/mock_remote_sync_service.dart';
import 'struct/sync/network_monitor.dart';
import 'struct/sync/sync_engine.dart';
import 'struct/sync/sync_global.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - ĐIỂM KHỞI CHẠY ỨNG DỤNG (ENTRY POINT)]
// File: lib/main.dart
// Đề tài: TH1 - Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew
// Mô tả: Khởi tạo cơ sở dữ liệu SQLite, tầng đồng bộ Offline-First
// (SyncEngine + RemoteSyncService + NetworkMonitor), thiết lập giao diện
// Theme (Light/Dark) và chạy màn hình chính HomePage.

// =====================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);


  database = AppDatabase();
  if (firebaseInitialized) {
    await database.setActiveOwner(FirebaseAuth.instance.currentUser?.uid);
  }
  await database.init();

  // Khởi tạo tầng đồng bộ Offline-First
  await _bootstrapSync();

  runApp(const StudyDocumentApp());
}


/// Khởi tạo SyncEngine + RemoteSyncService + NetworkMonitor toàn cục.
Future<void> _bootstrapSync() async {
  final fileStore = await createDefaultLocalFileStore();

  // Bản Cloud mặc định cho môi trường demo/offline (dễ thay bằng Firebase/AWS).
  final remote = MockRemoteSyncService();

  syncEngine = SyncEngine(
    database: database,
    remote: remote,
    fileStore: fileStore,
    ownerId: _resolveOwnerId(),
  );
  await syncEngine!.initialize();

  // Tự động đồng bộ khi mạng phục hồi (heartbeat tới Cloud).
  syncEngine!.bindNetworkMonitor(
    HeartbeatNetworkMonitor(remote: remote, interval: const Duration(seconds: 15)),
  );
}

String _resolveOwnerId() {
  try {
    return GoogleAuthService.instance.currentUser?.uid ?? 'local-device';
  } catch (_) {
    return 'local-device';
  }
}

class StudyDocumentApp extends StatelessWidget {

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

      title: 'Quản Lý Tài Liệu Học Tập (Kiến trúc Cashew)',

      debugShowCheckedModeBanner: false,
      theme: getLightTheme(),
      darkTheme: getDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}
