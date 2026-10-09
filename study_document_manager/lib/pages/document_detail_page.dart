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
import '../widgets/cloud/cloud_sync_badge.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';

class DocumentDetailPage extends StatefulWidget {
  const DocumentDetailPage({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  DocumentModel? _document;
  SubjectModel? _subject;
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final document = await database.getDocumentById(widget.documentId);
      final subject = document == null
          ? null
          : await database.getSubjectById(document.subjectId);
      if (!mounted) return;
      setState(() {
        _document = document;
        _subject = subject;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final document = _document;
    if (document == null || document.isShared) return;
    await DocumentService.toggleFavorite(document);
    await _load();
  }

  Future<void> _toggleStatus() async {
    final document = _document;
    if (document == null || document.isShared) return;
    await DocumentService.toggleStatus(document);
    await _load();
  }

  Future<void> _edit() async {
    final document = _document;
    if (document == null || document.isShared) return;
    final changed = await pushRoute<bool>(
      context,
      AddEditDocumentPage(initialDocument: document),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete() async {
    final document = _document;
    if (document == null || document.isShared) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ConfirmDeleteDialog(
        documentTitle: document.title,
        onConfirm: () async {
          try {
            await DocumentService.deleteDocument(document.id);
            if (mounted) {
              openSnackbar(context, message: 'Đã xóa tài liệu.');
              Navigator.pop(context, true);
            }
          } catch (error) {
            if (mounted) {
              openSnackbar(
                context,
                message: 'Không thể xóa tài liệu: $error',
                isError: true,
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _openSource(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null || !uri.hasScheme) {
        throw FormatException('Đường dẫn không hợp lệ: $value');
      }
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Không tìm thấy ứng dụng để mở liên kết.');
    } on PlatformException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể mở tài liệu: ${error.message ?? error.code}',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        openSnackbar(context, message: 'Không thể mở tài liệu: $error', isError: true);
      }
    }
  }

  Future<void> _openStorageObject(String storagePath) async {
    try {
      final url = await FirebaseStorageService.instance.downloadUrl(storagePath);
      await _openSource(url);
    } catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể tải tệp từ Firebase Storage: $error',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return PageFramework(
        title: 'Chi tiết tài liệu',
        body: Center(child: Text('Không thể tải tài liệu: $_loadError')),
      );
    }
    final document = _document;
    if (document == null) {
      return PageFramework(
        title: 'Không tìm thấy tài liệu',
        body: const Center(child: Text('Tài liệu đã bị xóa hoặc không tồn tại.')),
      );
    }

    final isAssignment = document.type == DocumentType.assignment;
    final isCompleted = document.status == DocumentStatus.completed;
    final sourceLabel = document.storagePath == null
        ? document.fileUrl
        : FirebaseStorageService.fileNameFromPath(document.storagePath!);

    return PageFramework(
      title: 'Chi tiết tài liệu',
      actions: [
        if (!document.isShared) ...[
          IconButton(
            onPressed: _toggleFavorite,
            tooltip: 'Yêu thích',
            icon: Icon(
              document.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: document.isFavorite ? AppColors.warning : null,
            ),
          ),
          IconButton(
            onPressed: _edit,
            tooltip: 'Chỉnh sửa',
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            onPressed: _delete,
            tooltip: 'Xóa',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (document.isShared)
                    const Chip(
                      avatar: Icon(Icons.people_outline_rounded),
                      label: Text('Tài liệu dùng chung · Chỉ đọc'),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(document.type.icon, color: document.type.color),
                        label: Text(document.type.displayName),
                      ),
                      if (_subject != null)
                        Chip(label: Text('${_subject!.code} · ${_subject!.name}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    document.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cập nhật ${DocumentFormatters.formatDateTime(document.updatedDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isAssignment) ...[
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle_outline
                            : Icons.pending_actions_outlined,
                        color: document.status.color,
                      ),
                      title: Text('Trạng thái: ${document.status.displayName}'),
                      subtitle: document.deadline == null
                          ? null
                          : Text(
                              'Hạn nộp: ${DocumentFormatters.formatDateTime(document.deadline)}',
                            ),
                      trailing: document.isShared
                          ? null
                          : IconButton(
                              tooltip: 'Đổi trạng thái',
                              onPressed: _toggleStatus,
                              icon: const Icon(Icons.swap_horiz_rounded),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (document.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ghi chú', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText(document.notes),
                  ],
                ),
              ),
            ),
          ],
          if (sourceLabel.isNotEmpty || document.localPath != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.attach_file_rounded),
                title: Text(sourceLabel.isEmpty ? 'Tệp lưu cục bộ' : sourceLabel),
                subtitle: document.storagePath != null
                    ? const CloudSyncBadge(fileUrl: null)
                    : Text(document.localPath ?? document.fileUrl),
                trailing: sourceLabel.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Mở tài liệu',
                        onPressed: document.storagePath != null
                            ? () => _openStorageObject(document.storagePath!)
                            : () => _openSource(document.fileUrl),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
              ),
            ),
          ],
          if (document.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: document.tags.map((tag) => Chip(label: Text('#$tag'))).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
