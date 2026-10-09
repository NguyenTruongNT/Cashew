import 'package:flutter/material.dart';

import '../colors.dart';
import '../struct/formatters.dart';
import '../struct/sync/sync_engine.dart';
import '../struct/sync/sync_global.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN TÁI SỬ DỤNG: SYNC STATUS BANNER]
// File: lib/widgets/sync_status_banner.dart
// Mô tả: Thẻ trạng thái đồng bộ Offline-First hiển thị trên Dashboard:
//   - Trực tuyến / Ngoại tuyến.
//   - Số thay đổi đang chờ đẩy lên Cloud (pending).
//   - Nút "Đồng bộ ngay" và trạng thái đang đồng bộ.
// Tự động cập nhật nhờ lắng nghe ValueNotifier<SyncSnapshot> của SyncEngine.
// =====================================================================

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key, this.engine, this.onSyncNow});

  /// Cho phép truyền SyncEngine tường minh (phục vụ test); mặc định dùng
  /// SyncEngine toàn cục.
  final SyncEngine? engine;

  /// Ghi đè hành vi nút "Đồng bộ ngay" (phục vụ test); mặc định gọi
  /// [SyncEngine.syncNow].
  final VoidCallback? onSyncNow;

  SyncEngine? get _engine => engine ?? syncEngine;

  @override
  Widget build(BuildContext context) {
    final activeEngine = _engine;
    if (activeEngine == null) {
      return _buildShell(
        context,
        color: AppColors.info,
        icon: Icons.cloud_off_rounded,
        title: 'Chỉ lưu cục bộ',
        subtitle: 'Tầng đồng bộ Cloud chưa được bật',
      );
    }

    return ValueListenableBuilder<SyncSnapshot>(
      valueListenable: activeEngine.snapshot,
      builder: (context, snapshot, _) =>
          _buildSnapshot(context, activeEngine, snapshot),
    );
  }

  Widget _buildSnapshot(
    BuildContext context,
    SyncEngine engine,
    SyncSnapshot snap,
  ) {
    final syncing = snap.phase == SyncPhase.syncing;
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (!snap.isOnline) {
      color = AppColors.warning;
      icon = Icons.cloud_off_rounded;
      title = 'Đang ngoại tuyến';
      subtitle = snap.pendingCount > 0
          ? '${snap.pendingCount} thay đổi chờ đồng bộ khi có mạng'
          : 'Thay đổi sẽ được đồng bộ khi có mạng trở lại';
    } else if (syncing) {
      color = AppColors.info;
      icon = Icons.sync_rounded;
      title = 'Đang đồng bộ...';
      subtitle = 'Đang trao đổi dữ liệu với Cloud';
    } else if (snap.phase == SyncPhase.error) {
      color = AppColors.error;
      icon = Icons.error_outline_rounded;
      title = 'Đồng bộ gặp lỗi';
      subtitle = snap.lastResult?.summary ??
          '${snap.pendingCount} mục đang chờ đồng bộ';
    } else if (snap.pendingCount > 0) {
      color = AppColors.warning;
      icon = Icons.cloud_upload_rounded;
      title = '${snap.pendingCount} mục chờ đồng bộ';
      subtitle = 'Đang chờ kết nối để đẩy lên Cloud';
    } else {
      color = AppColors.success;
      icon = Icons.cloud_done_rounded;
      title = 'Đã đồng bộ Cloud';
      subtitle = snap.lastSyncAt == null
          ? 'Chưa đồng bộ lần nào'
          : 'Lần cuối: ${DocumentFormatters.formatDateTime(snap.lastSyncAt!)}';
    }

    return _buildShell(
      context,
      color: color,
      icon: icon,
      title: title,
      subtitle: subtitle,
      engine: engine,
      syncing: syncing,
      onSyncNow: onSyncNow,
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    SyncEngine? engine,
    bool syncing = false,
    VoidCallback? onSyncNow,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (syncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
            )
          else
            Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (engine != null)
            IconButton(
              tooltip: 'Đồng bộ ngay',
              onPressed:
                  syncing ? null : (onSyncNow ?? () => engine.syncNow()),
              icon: const Icon(Icons.sync_rounded, size: 20),
              color: color,
            ),
        ],
      ),
    );
  }
}
