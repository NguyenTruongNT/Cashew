import 'package:flutter/material.dart';
import 'colors.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG TIỆN ÍCH TOÀN CỤC (GLOBAL FUNCTIONS & UTILITIES)]
// File: lib/functions.dart
// Mô tả: Cung cấp các hàm điều hướng (Navigation), hiển thị thông báo
// (Snackbar/Dialog), định dạng hiển thị dữ liệu dùng chung cho toàn bộ app.
// =====================================================================

/// Điều hướng tới một màn hình mới (Push Route)
Future<T?> pushRoute<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    MaterialPageRoute(builder: (context) => page),
  );
}

/// Điều hướng thay thế màn hình hiện tại (Push Replacement)
Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
  return Navigator.pushReplacement<T, TO>(
    context,
    MaterialPageRoute(builder: (context) => page),
  );
}

/// Hiển thị thông báo nhanh (Floating Snackbar) phong cách Cashew
void openSnackbar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      backgroundColor: isError ? AppColors.error : const Color(0xFF323232),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: duration,
      action: actionLabel != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: AppColors.accent,
              onPressed: onAction ?? () {},
            )
          : null,
    ),
  );
}

/// Hiển thị Bottom Sheet tùy biến chuẩn Cashew
Future<T?> openBottomSheetCustom<T>(
  BuildContext context, {
  required Widget child,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: child,
    ),
  );
}
