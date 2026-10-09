import 'package:flutter/material.dart';
import '../../colors.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN DÙNG CHUNG: THANH TIẾN TRÌNH CLOUD]
// File: lib/widgets/cloud/transfer_progress_bar.dart
// Người thực hiện: Vũ Hải Đăng
// Mô tả: Thanh tiến trình tải tệp lên / xuống (Upload / Download Progress Bar)
// hiển thị dung lượng byte đã truyền, phần trăm, nút hủy và trạng thái lỗi.
// =====================================================================

class TransferProgressBar extends StatelessWidget {
  final bool isUpload;
  final String? fileName;
  final int transferredBytes;
  final int? totalBytes;
  final VoidCallback? onCancel;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const TransferProgressBar({
    super.key,
    required this.isUpload,
    this.fileName,
    required this.transferredBytes,
    this.totalBytes,
    this.onCancel,
    this.errorMessage,
    this.onRetry,
  });

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  double? get progress {
    if (totalBytes == null || totalBytes! <= 0) return null;
    return (transferredBytes / totalBytes!).clamp(0.0, 1.0);
  }

  int get percentage {
    final p = progress;
    if (p == null) return 0;
    return (p * 100).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorMessage != null && errorMessage!.isNotEmpty;
    final color = hasError
        ? theme.colorScheme.error
        : (isUpload ? AppColors.primary : AppColors.accent);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Biểu tượng + Tiêu đề + Phần trăm
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasError
                      ? Icons.error_outline_rounded
                      : (isUpload
                          ? Icons.cloud_upload_rounded
                          : Icons.cloud_download_rounded),
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasError
                          ? (isUpload
                              ? 'Tải tệp lên thất bại'
                              : 'Tải tệp xuống thất bại')
                          : (isUpload
                              ? 'Đang tải tệp lên Cloud...'
                              : 'Đang tải tệp xuống...'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (fileName != null && fileName!.isNotEmpty)
                      Text(
                        fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (!hasError && progress != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Thanh tiến trình LinearProgressIndicator
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: hasError ? 0.0 : progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 7,
            ),
          ),

          const SizedBox(height: 8),

          // Footer: Dung lượng byte + Nút hủy/thử lại
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hasError
                      ? errorMessage!
                      : '${_formatBytes(transferredBytes)}'
                          '${totalBytes != null ? ' / ${_formatBytes(totalBytes!)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: hasError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (hasError && onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử lại', style: TextStyle(fontSize: 12)),
                )
              else if (!hasError && onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Hủy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
