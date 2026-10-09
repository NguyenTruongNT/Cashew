import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/firebase_platform_support.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/formatters.dart';
import '../struct/models/document_models.dart';
import '../widgets/cloud/transfer_progress_bar.dart';
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
  UploadTask? _uploadTask;
  StreamSubscription<TaskSnapshot>? _uploadSubscription;
  bool _isUploading = false;
  bool _isDownloading = false;
  int _transferredBytes = 0;
  int? _totalBytes;
  String? _transferError;
  String? _transferFileName;
  bool _lastTransferWasUpload = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    unawaited(_uploadSubscription?.cancel());
    super.dispose();
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
        _transferError = null;
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
          await DocumentService.deleteDocument(_document!.id);
          if (mounted) {
            openSnackbar(context, message: 'Đã xóa tài liệu thành công!');
            Navigator.pop(context, true);
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
      openSnackbar(
        context,
        message: 'Chỉ hỗ trợ đường dẫn web hoặc đường dẫn tệp.',
      );
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
          message:
              'Không thể mở nguồn tài liệu: ${error.message ?? error.code}',
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

  Future<void> _pickAndUploadFile() async {
    final doc = _document;
    if (doc == null) return;

    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png',
          'txt',
        ],
      );
      if (selection.isEmpty) return;

      final file = selection.single;
      setState(() {
        _lastTransferWasUpload = true;
        _transferFileName = file.name;
        _transferError = null;
      });
      final fileSize = await file.length();
      if (fileSize == null) {
        throw const FormatException('Không xác định được kích thước tệp đã chọn.');
      }
      if (fileSize > FirebaseStorageService.maxFileSizeBytes) {
        throw const FormatException('Kích thước tệp không được vượt quá 25 MB.');
      }
      final bytes = await file.readAsBytes();

      setState(() {
        _isUploading = true;
        _isDownloading = false;
        _transferredBytes = 0;
        _totalBytes = bytes.lengthInBytes;
        _transferError = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      var uploadedToCloud = false;
      String finalUrl = '';

      if (user != null && canUploadToCloud) {
        bool cloudAttemptFailed = false;
        try {
          final operation = FirebaseStorageService.createUpload(
            userId: user.uid,
            documentId: doc.id,
            fileName: file.name,
            bytes: bytes,
          );
          _uploadTask = operation.task;
          _uploadSubscription = operation.task.snapshotEvents.listen(
            (snapshot) {
              if (!mounted) return;
              setState(() {
                _transferredBytes = snapshot.bytesTransferred;
                _totalBytes = snapshot.totalBytes;
              });
            },
            onError: (Object error) {
              if (error is FirebaseException && error.code == 'canceled') {
                return;
              }
              if (mounted) {
                setState(() => _transferError = error.toString());
              }
            },
          );

          // Chờ Storage hoàn thành (không timeout: để user hủy thủ công nếu cần)
          await operation.task;
          finalUrl = operation.documentValue;
          uploadedToCloud = true;
        } on FirebaseException catch (e) {
          debugPrint('Firebase upload thất bại (${e.code}), dùng fallback cục bộ: $e');
          cloudAttemptFailed = true;
        } catch (e) {
          debugPrint('Lỗi upload không xác định, dùng fallback cục bộ: $e');
          cloudAttemptFailed = true;
        } finally {
          await _uploadSubscription?.cancel();
          _uploadSubscription = null;
          _uploadTask = null;
        }

        // Fallback: lưu cục bộ nếu cloud thất bại
        if (cloudAttemptFailed) {
          if (mounted) setState(() => _transferError = null);
          finalUrl = FirebaseStorageService.saveLocalAttachment(
            documentId: doc.id,
            fileName: file.name,
            bytes: bytes,
          );
        }
      } else {
        // Lưu tệp đính kèm cục bộ (offline / Desktop / chưa đăng nhập)
        finalUrl = FirebaseStorageService.saveLocalAttachment(
          documentId: doc.id,
          fileName: file.name,
          bytes: bytes,
        );
      }

      final updatedDocument = doc.copyWith(
        fileUrl: finalUrl,
        updatedDate: DateTime.now(),
      );
      await DocumentService.updateDocument(updatedDocument);
      await _loadData();

      if (mounted) {
        openSnackbar(
          context,
          message: uploadedToCloud
              ? 'Đã tải tệp lên Cloud Storage thành công!'
              : 'Đã lưu tệp đính kèm thành công vào thiết bị!',
        );
      }
    } on FirebaseException catch (error) {
      if (error.code != 'canceled') {
        _showTransferError(
          'Không thể tải tệp lên (${error.code}): '
          '${error.message ?? 'Firebase Storage từ chối yêu cầu.'}',
        );
      }
    } on PlatformException catch (error) {
      _showTransferError(
        'Không thể chọn/lưu tệp: ${error.message ?? error.code}',
      );
    } on FormatException catch (error) {
      _showTransferError('Không thể tải tệp lên: ${error.message}');
    } on Exception catch (error) {
      _showTransferError('Không thể tải tệp lên: $error');
    } finally {
      await _uploadSubscription?.cancel();
      _uploadSubscription = null;
      _uploadTask = null;
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _downloadFile(String fileUrl) async {
    setState(() {
      _lastTransferWasUpload = false;
      _transferFileName = FirebaseStorageService.fileNameFromPath(fileUrl);
      _isDownloading = true;
      _isUploading = false;
      _transferredBytes = 0;
      _totalBytes = null;
      _transferError = null;
    });

    try {
      // Pass fileUrl as-is; FirebaseStorageService.download() normalizes it internally.
      final result = await FirebaseStorageService.download(
        storagePath: fileUrl,
        onProgress: (transferredBytes, totalBytes) {
          if (!mounted) return;
          setState(() {
            _transferredBytes = transferredBytes;
            _totalBytes = totalBytes;
          });
        },
      );
      if (mounted) {
        openSnackbar(
          context,
          message: result == null
              ? 'Đã mở tải tệp.'
              : 'Đã tải tệp xuống thiết bị thành công!',
        );
      }
    } on FirebaseException catch (error) {
      _showTransferError(
        'Không thể tải tệp xuống: ${error.message ?? error.code}',
      );
    } on PlatformException catch (error) {
      _showTransferError(
        'Không thể lưu tệp xuống thiết bị: ${error.message ?? error.code}',
      );
    } on StateError catch (error) {
      _showTransferError('Không thể tải tệp xuống: ${error.message}');
    } on Exception catch (error) {
      _showTransferError('Không thể tải tệp xuống: $error');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _cancelUpload() async {
    final sub = _uploadSubscription;
    _uploadSubscription = null;
    await sub?.cancel();
    final task = _uploadTask;
    _uploadTask = null;
    if (task != null) {
      try {
        await task.cancel();
      } catch (e) {
        debugPrint('Lỗi hủy upload: $e');
      }
    }
    if (mounted) {
      setState(() {
        _isUploading = false;
        _transferError = null;
      });
      openSnackbar(context, message: 'Đã hủy tải tệp lên.');
    }
  }

  void _showTransferError(String message) {
    if (!mounted) return;
    setState(() => _transferError = message);
    openSnackbar(context, message: message, isError: true);
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
        if (!doc.isShared) ...[
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
                  if (doc.isShared) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tài liệu dùng chung · Chỉ đọc',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
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
                          mainAxisSize: MainAxisSize.min,
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
                      Expanded(
                        child: Text(
                          'Cập nhật: ${DocumentFormatters.formatDateTime(doc.updatedDate)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
                        onPressed: doc.isShared ? null : _toggleStatus,
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
                  Row(
                    children: [
                      const Icon(
                        Icons.notes_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ghi chú & Tóm tắt',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        size: 20,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tệp đính kèm',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!doc.isShared)
                        IconButton(
                          onPressed: _isUploading || _isDownloading
                              ? null
                              : _pickAndUploadFile,
                          tooltip: doc.fileUrl.isEmpty
                              ? 'Đính kèm tệp'
                              : 'Thay thế tệp đính kèm',
                          icon: const Icon(Icons.upload_file_rounded),
                        ),
                    ],
                  ),
                  if (doc.fileUrl.isNotEmpty) ...[
                    const Divider(height: 20),
                    Builder(
                      builder: (context) {
                        final storagePath =
                            FirebaseStorageService.pathFromValue(doc.fileUrl);
                        final fileName = storagePath == null
                            ? FirebaseStorageService.fileNameFromPath(doc.fileUrl)
                            : FirebaseStorageService.fileNameFromPath(
                                storagePath,
                              );
                        final isWebUrl = doc.fileUrl.startsWith('http://') ||
                            doc.fileUrl.startsWith('https://');
                        return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isWebUrl
                                          ? Icons.link_rounded
                                          : Icons.cloud_done_rounded,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isWebUrl) ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            _openDocumentLink(doc.fileUrl),
                                        tooltip: 'Mở liên kết',
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () => _copyLink(doc.fileUrl),
                                        tooltip: 'Sao chép liên kết',
                                      ),
                                    ] else ...[
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          size: 20,
                                        ),
                                        onPressed: _isUploading || _isDownloading
                                            ? null
                                            : () => _downloadFile(doc.fileUrl),
                                        tooltip: 'Tải xuống tệp',
                                      ),
                                    ],
                                  ],
                                ),
                              );
                      },
                    ),
                  ] else
                    Text(
                      doc.isShared
                          ? 'Tài liệu dùng chung chưa có tệp đính kèm.'
                          : 'Chưa có tệp. Tải lên PDF, Office, ảnh hoặc TXT (tối đa 25 MB).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_isUploading || _isDownloading) ...[
                    TransferProgressBar(
                      isUpload: _isUploading,
                      fileName: doc.fileUrl.isNotEmpty
                          ? FirebaseStorageService.fileNameFromPath(
                              FirebaseStorageService.pathFromValue(doc.fileUrl) ?? doc.fileUrl,
                            )
                          : null,
                      transferredBytes: _transferredBytes,
                      totalBytes: _totalBytes,
                      onCancel: _isUploading ? _cancelUpload : null,
                      errorMessage: _transferError,
                    ),
                  ] else if (_transferError != null) ...[
                    TransferProgressBar(
                      isUpload: _lastTransferWasUpload,
                      fileName: _transferFileName,
                      transferredBytes: _transferredBytes,
                      totalBytes: _totalBytes,
                      errorMessage: _transferError,
                      onRetry: _lastTransferWasUpload
                          ? () => _pickAndUploadFile()
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

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
                    Row(
                      children: [
                        const Icon(
                          Icons.tag_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thẻ phân loại (Tags)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.10,
                          ),
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
