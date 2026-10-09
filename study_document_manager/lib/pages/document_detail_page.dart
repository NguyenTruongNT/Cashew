import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/formatters.dart';
import '../struct/models/document_models.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: CHI TIẾT TÀI LIỆU]
// File: lib/pages/document_detail_page.dart
// Mô tả: Màn hình hiển thị chi tiết tài liệu học tập, bao gồm toàn bộ
// thông tin, ghi chú, liên kết, tình trạng nộp bài và các thao tác Sửa/Xóa.
// =====================================================================

class DocumentDetailPage extends StatefulWidget {
  final String documentId;

  const DocumentDetailPage({super.key, required this.documentId});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  SubjectModel? _subject;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await database.getDocumentById(widget.documentId);
    SubjectModel? sub;
    if (doc != null) {
      sub = await database.getSubjectById(doc.subjectId);
    }

    if (mounted) {
      setState(() {
        _document = doc;
        _subject = sub;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_document == null) return;
    await DocumentService.toggleFavorite(_document!);
    await _loadData();
  }

  Future<void> _toggleStatus() async {
    if (_document == null) return;
    await DocumentService.toggleStatus(_document!);
    await _loadData();
  }

  void _onEdit() async {
    if (_document == null) return;
    final res = await pushRoute(
      context,
      AddEditDocumentPage(initialDocument: _document),
    );
    if (res == true) {
      await _loadData();
    }
  }

  void _onDelete() {
    if (_document == null) return;
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDeleteDialog(
        documentTitle: _document!.title,
        onConfirm: () async {
          try {
            await DocumentService.deleteDocument(_document!.id);
            if (mounted) {
              openSnackbar(context, message: 'Đã xóa tài liệu thành công!');
              Navigator.pop(context, true);
            }
          } on FirebaseException catch (error) {
            if (mounted) {
              openSnackbar(
                context,
                message: 'Không thể xóa tệp Firebase: ${error.message ?? error.code}',
                isError: true,
              );
            }
          } catch (error) {
            if (mounted) {
              openSnackbar(context, message: 'Lỗi khi xóa tài liệu: $error', isError: true);
            }
          }
        },
      ),
    );
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    openSnackbar(context, message: 'Đã sao chép liên kết vào bộ nhớ tạm!');
  }

  Future<void> _openDocumentLink(String source) async {
    final value = source.trim();
    final parsedUri = Uri.tryParse(value);
    if (parsedUri == null || value.isEmpty) {
      openSnackbar(context, message: 'Đường dẫn tài liệu không hợp lệ.');
      return;
    }

    final uri = parsedUri.hasScheme ? parsedUri : Uri.file(value);
    if (!['http', 'https', 'file'].contains(uri.scheme.toLowerCase())) {
      openSnackbar(context, message: 'Chỉ hỗ trợ đường dẫn web hoặc đường dẫn tệp.');
      return;
    }

    try {
      final didLaunch = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch && mounted) {
        openSnackbar(context, message: 'Không thể mở nguồn tài liệu này.');
      }
    } on PlatformException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể mở nguồn tài liệu: ${error.message ?? error.code}',
        );
      }
    } on UnsupportedError {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Nền tảng hiện tại không hỗ trợ mở đường dẫn tệp này.',
        );
      }
    }
  }

  Future<void> _openCloudDocument(String storagePath) async {
    try {
      final url = await FirebaseStorageService.instance.downloadUrl(storagePath);
      await _openDocumentLink(url);
    } on FirebaseException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể tải tệp Firebase: ${error.message ?? error.code}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_document == null) {
      return PageFramework(
        title: 'Tài liệu không tồn tại',
        body: const Center(
          child: Text('Tài liệu đã bị xóa hoặc không tìm thấy'),
        ),
      );
    }

    final doc = _document!;
    final typeColor = doc.type.color;
    final isAssignment = doc.type == DocumentType.assignment;
    final isCompleted = doc.status == DocumentStatus.completed;
    final statusColor = doc.status.color;

    return PageFramework(
      title: 'Chi tiết tài liệu',
      actions: [
        IconButton(
          icon: Icon(
            doc.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: doc.isFavorite ? AppColors.warning : null,
          ),
          onPressed: _toggleFavorite,
          tooltip: 'Yêu thích',
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: _onEdit,
          tooltip: 'Chỉnh sửa',
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
          ),
          onPressed: _onDelete,
          tooltip: 'Xóa tài liệu',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card thông tin chính
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Badge loại
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(doc.type.icon, size: 16, color: typeColor),
                            const SizedBox(width: 6),
                            Text(
                              doc.type.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Môn học
                      if (_subject != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _subject!.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '[${_subject!.code}] ${_subject!.name}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _subject!.color,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tiêu đề
                  Text(
                    doc.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Ngày cập nhật
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cập nhật: ${DocumentFormatters.formatDateTime(doc.updatedDate)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nếu là bài tập: Khung trạng thái nộp bài và Deadline
          if (isAssignment) ...[
            Card(
              color: statusColor.withValues(alpha: 0.10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.pending_actions_rounded,
                          color: statusColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trạng thái: ${doc.status.displayName}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: statusColor,
                                ),
                              ),
                              if (doc.deadline != null)
                                Text(
                                  'Hạn nộp: ${DocumentFormatters.formatDateTime(doc.deadline)} (${DocumentFormatters.formatRemainingTime(doc.deadline)})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: statusColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted
                              ? Theme.of(context).colorScheme.secondary
                              : AppColors.primary,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _toggleStatus,
                        icon: Icon(
                          isCompleted
                              ? Icons.undo_rounded
                              : Icons.check_circle_outline,
                        ),
                        label: Text(
                          isCompleted
                              ? 'Đổi thành: Chưa xong'
                              : 'Xác nhận: Đã nộp bài tập',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Ghi chú & Tóm tắt
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ghi chú & Tóm tắt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    doc.notes.isNotEmpty
                        ? doc.notes
                        : 'Không có ghi chú nào cho tài liệu này.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: doc.notes.isNotEmpty
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Liên kết tài liệu / File đính kèm
          if (doc.fileUrl.isNotEmpty || doc.storagePath != null) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.attachment_rounded,
                          size: 20,
                          color: AppColors.accent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đường dẫn / Tệp đính kèm',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: doc.storagePath != null
                                  ? () => _openCloudDocument(doc.storagePath!)
                                  : () => _openDocumentLink(doc.fileUrl),
                              child: Text(
                                doc.storagePath == null
                                    ? doc.fileUrl
                                    : doc.storagePath!.split('/').last,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            onPressed: doc.storagePath != null
                                ? () => _openCloudDocument(doc.storagePath!)
                                : () => _openDocumentLink(doc.fileUrl),
                            tooltip: 'Mở tài liệu',
                          ),
                          if (doc.storagePath == null)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () => _copyLink(doc.fileUrl),
                              tooltip: 'Sao chép liên kết',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Thẻ phân loại (Tags)
          if (doc.tags.isNotEmpty) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.tag_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thẻ phân loại (Tags)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doc.tags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
