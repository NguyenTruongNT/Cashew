import 'package:flutter/material.dart';
import '../colors.dart';
import '../struct/formatters.dart';
import '../struct/models/document_models.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN TÁI SỬ DỤNG: THẺ TÀI LIỆU (DOCUMENT CARD)]
// File: lib/widgets/document_card.dart
// Mô tả: Card hiển thị tài liệu — màu sắc nhất quán theo chủ đề Indigo-Blue,
// tỉ lệ văn bản cân đối, bo góc đẹp, thân thiện Chrome & mobile.
// =====================================================================

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final SubjectModel? subject;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onStatusToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    this.subject,
    this.onTap,
    this.onFavoriteToggle,
    this.onStatusToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = document.type.color;
    final isAssignment = document.type == DocumentType.assignment;
    final isCompleted = document.status == DocumentStatus.completed;

    // Màu viền trái theo loại tài liệu (accent strip)
    final borderColor = isCompleted
        ? AppColors.statusCompleted
        : typeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Material(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: typeColor.withValues(alpha: 0.08),
          highlightColor: typeColor.withValues(alpha: 0.04),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: borderColor, width: 4),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hàng trên: Badge loại + Môn học + Actions ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Badge loại tài liệu
                      _TypeBadge(type: document.type, color: typeColor),
                      const SizedBox(width: 6),

                      // Mã môn học
                      if (subject != null)
                        _SubjectBadge(subject: subject!),

                      const Spacer(),

                      // Nút yêu thích
                      GestureDetector(
                        onTap: onFavoriteToggle,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            document.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: document.isFavorite
                                ? const Color(0xFFFFBF00)
                                : (isDark ? AppColors.textHintDark : AppColors.textHintLight),
                            size: 20,
                          ),
                        ),
                      ),

                      // Menu 3 chấm
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: isDark ? AppColors.textHintDark : AppColors.textHintLight,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                          if (val == 'edit' && onEdit != null) onEdit!();
                          if (val == 'delete' && onDelete != null) onDelete!();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              const Text('Chỉnh sửa', style: TextStyle(fontSize: 14)),
                            ]),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                              const SizedBox(width: 8),
                              const Text('Xóa', style: TextStyle(color: AppColors.error, fontSize: 14)),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 9),

                  // ── Tiêu đề tài liệu ──
                  Text(
                    document.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? (isDark ? AppColors.textHintDark : AppColors.textHintLight)
                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: isDark ? AppColors.textHintDark : AppColors.textHintLight,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // ── Ghi chú tóm tắt ──
                  if (document.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      document.notes,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ── Hàng cuối: Deadline / Tags / Trạng thái ──
                  _CardFooter(
                    document: document,
                    isDark: isDark,
                    isAssignment: isAssignment,
                    isCompleted: isCompleted,
                    onStatusToggle: onStatusToggle,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widget badge loại tài liệu ──
class _TypeBadge extends StatelessWidget {
  final DocumentType type;
  final Color color;
  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget badge môn học ──
class _SubjectBadge extends StatelessWidget {
  final SubjectModel subject;
  const _SubjectBadge({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = subject.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        subject.code.isNotEmpty ? subject.code : subject.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Footer card ──
class _CardFooter extends StatelessWidget {
  final DocumentModel document;
  final bool isDark;
  final bool isAssignment;
  final bool isCompleted;
  final VoidCallback? onStatusToggle;
  const _CardFooter({
    required this.document,
    required this.isDark,
    required this.isAssignment,
    required this.isCompleted,
    this.onStatusToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = isDark ? AppColors.textHintDark : AppColors.textHintLight;

    return Row(
      children: [
        // Ngày cập nhật
        Icon(Icons.history_rounded, size: 13, color: hintColor),
        const SizedBox(width: 3),
        Text(
          DocumentFormatters.formatDate(document.updatedDate),
          style: TextStyle(fontSize: 11.5, color: hintColor),
        ),

        // Deadline nếu có
        if (isAssignment && document.deadline != null) ...[
          const SizedBox(width: 8),
          const Text('·', style: TextStyle(color: AppColors.textHintLight)),
          const SizedBox(width: 8),
          _DeadlineChip(deadline: document.deadline!, isCompleted: isCompleted),
        ],

        const Spacer(),

        // Nút trạng thái bài tập
        if (isAssignment)
          GestureDetector(
            onTap: onStatusToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.statusCompleted.withValues(alpha: 0.13)
                    : AppColors.statusPending.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 13,
                    color: isCompleted ? AppColors.statusCompleted : AppColors.statusPending,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCompleted ? 'Hoàn thành' : 'Chưa nộp',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCompleted ? AppColors.statusCompleted : AppColors.statusPending,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (document.fileUrl.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 13, color: AppColors.primary),
              const SizedBox(width: 3),
              const Text(
                'Có liên kết',
                style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Chip deadline ──
class _DeadlineChip extends StatelessWidget {
  final DateTime deadline;
  final bool isCompleted;
  const _DeadlineChip({required this.deadline, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final isOverdue = deadline.isBefore(DateTime.now()) && !isCompleted;
    final color = isOverdue ? AppColors.error : AppColors.statusPending;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          DocumentFormatters.formatRemainingTime(deadline),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
