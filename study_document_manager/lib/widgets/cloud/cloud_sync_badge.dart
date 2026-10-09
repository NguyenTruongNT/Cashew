import 'package:flutter/material.dart';
import '../../colors.dart';
import '../../struct/firebase_storage_service.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN DÙNG CHUNG: CHỈ BÁO TRẠNG THÁI CLOUD]
// File: lib/widgets/cloud/cloud_sync_badge.dart
// Người thực hiện: Vũ Hải Đăng
// Mô tả: Widget hiển thị chỉ báo đồng bộ Cloud (Cloud Sync Badge) và
// chỉ báo chế độ ngoại tuyến (Offline Mode Indicator).
// =====================================================================

enum CloudSyncStatus {
  syncedCloud,
  webLink,
  localFile,
  none,
}

class CloudSyncBadge extends StatelessWidget {
  final String? fileUrl;
  final bool compact;

  const CloudSyncBadge({
    super.key,
    required this.fileUrl,
    this.compact = false,
  });

  CloudSyncStatus get status {
    final url = fileUrl?.trim() ?? '';
    if (url.isEmpty) return CloudSyncStatus.none;
    if (FirebaseStorageService.isStorageValue(url)) return CloudSyncStatus.syncedCloud;
    if (url.startsWith('http://') || url.startsWith('https://')) return CloudSyncStatus.webLink;
    return CloudSyncStatus.localFile;
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = status;
    if (currentStatus == CloudSyncStatus.none) return const SizedBox.shrink();

    final Color badgeColor;
    final IconData icon;
    final String label;

    switch (currentStatus) {
      case CloudSyncStatus.syncedCloud:
        badgeColor = AppColors.primary;
        icon = Icons.cloud_done_rounded;
        label = 'Cloud Storage';
        break;
      case CloudSyncStatus.webLink:
        badgeColor = AppColors.accent;
        icon = Icons.link_rounded;
        label = 'Liên kết Web';
        break;
      case CloudSyncStatus.localFile:
        badgeColor = const Color(0xFF5C6BC0);
        icon = Icons.insert_drive_file_outlined;
        label = 'Tệp đính kèm';
        break;
      case CloudSyncStatus.none:
        return const SizedBox.shrink();
    }

    if (compact) {
      return Tooltip(
        message: 'Trạng thái lưu trữ: $label',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: badgeColor),
              const SizedBox(width: 3.5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: badgeColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chỉ báo chế độ ngoại tuyến (Offline Mode Indicator)
class OfflineModeBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const OfflineModeBanner({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chế độ ngoại tuyến (Offline Mode)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  'Đang sử dụng dữ liệu cục bộ SQLite. Các tính năng tải lên/xuống Cloud tạm dừng.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: onRetry,
              tooltip: 'Thử kết nối lại',
            ),
        ],
      ),
    );
  }
}
