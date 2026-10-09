import 'package:flutter/material.dart';
import 'framework/popup_framework.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN TÁI SỬ DỤNG: CONFIRM DELETE DIALOG]
// File: lib/widgets/confirm_delete_dialog.dart
// Mô tả: Hộp thoại xác nhận thao tác xóa tài liệu để tránh người dùng bấm nhầm.
// =====================================================================

class ConfirmDeleteDialog extends StatelessWidget {
  final String documentTitle;
  final VoidCallback onConfirm;

  const ConfirmDeleteDialog({
    super.key,
    required this.documentTitle,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return PopupFramework(
      title: 'Xác nhận xóa tài liệu',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red,
      content: Text(
        'Bạn có chắc chắn muốn xóa tài liệu "$documentTitle" không?\nHành động này không thể hoàn tác.',
        style: const TextStyle(fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy bỏ', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: const Text('Xác nhận xóa'),
        ),
      ],
    );
  }
}
