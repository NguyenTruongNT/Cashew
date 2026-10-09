import 'app_database.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG DỮ LIỆU: BIẾN TOÀN CỤC CƠ SỞ DỮ LIỆU (DATABASE GLOBAL)]
// File: lib/database/databaseGlobal.dart
// Mô tả: Khai báo Singleton Instance toàn cục của AppDatabase, cho phép
// toàn bộ ứng dụng truy cập nhất quán theo đúng quy chuẩn kiến trúc Cashew.
// =====================================================================

late AppDatabase database;
