import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/firebase_platform_support.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/formatters.dart';
import '../struct/models/document_models.dart';
import '../widgets/cloud/cloud_sync_badge.dart';
import '../widgets/cloud/transfer_progress_bar.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/framework/page_framework.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: THÊM & SỬA TÀI LIỆU]
// File: lib/pages/add_edit_document_page.dart
// Mô tả: Màn hình xử lý đồng thời chức năng THÊM MỚI (Create) và CHỈNH SỬA (Update)
// tài liệu học tập theo Checklist 3 của đề tài.
// =====================================================================

class AddEditDocumentPage extends StatefulWidget {
  final DocumentModel? initialDocument;
  final String? defaultSubjectId;

  const AddEditDocumentPage({
    super.key,
    this.initialDocument,
    this.defaultSubjectId,
  });

  @override
  State<AddEditDocumentPage> createState() => _AddEditDocumentPageState();
}

class _AddEditDocumentPageState extends State<AddEditDocumentPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _fileUrlController;
  late final TextEditingController _tagsController;

  String _subjectInput = '';
  late DocumentType _selectedType;
  late PriorityLevel _selectedPriority;
  late bool _isFavorite;
  String? _selectedSubjectId;
  DateTime? _selectedDeadline;
  List<SubjectModel> _availableSubjects = [];
  bool _isLoadingSubjects = true;

  // Trạng thái tải tệp (Upload State - Vũ Hải Đăng)
  UploadTask? _uploadTask;
  StreamSubscription<TaskSnapshot>? _uploadSubscription;
  bool _isUploading = false;
  int _transferredBytes = 0;
  int? _totalBytes;
  String? _transferError;
  String? _pickedFileName;
  bool _showCustomUrlInput = false;

  bool get isEditing => widget.initialDocument != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.initialDocument;

    _titleController = TextEditingController(text: doc?.title ?? '');
    _notesController = TextEditingController(text: doc?.notes ?? '');
    _fileUrlController = TextEditingController(text: doc?.fileUrl ?? '');
    _tagsController = TextEditingController(text: doc?.tags.join(', ') ?? '');

    _selectedType = doc?.type ?? DocumentType.lecture;
    _selectedPriority = doc?.priority ?? PriorityLevel.medium;
    _isFavorite = doc?.isFavorite ?? false;
    _selectedSubjectId = doc?.subjectId ?? widget.defaultSubjectId;
    _selectedDeadline = doc?.deadline;

    if (doc?.fileUrl.isNotEmpty == true) {
      final fileUrl = doc!.fileUrl;
      if (FirebaseStorageService.isStorageValue(fileUrl)) {
        final path = FirebaseStorageService.pathFromValue(fileUrl);
        if (path != null) {
          _pickedFileName = FirebaseStorageService.fileNameFromPath(path);
        }
      } else if (!fileUrl.startsWith('http://') &&
          !fileUrl.startsWith('https://')) {
        _pickedFileName = fileUrl;
      } else {
        _showCustomUrlInput = true;
      }
    }

    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final list = await database.getAllSubjects();
      if (mounted) {
        setState(() {
          _availableSubjects = list;
          final selectedSubject = list.where((s) => s.id == _selectedSubjectId);
          if (selectedSubject.isNotEmpty) {
            _subjectInput =
                '${selectedSubject.first.code} - ${selectedSubject.first.name}';
          }
          _isLoadingSubjects = false;
        });
      }
    } catch (e) {
      debugPrint('Lỗi nạp danh sách môn học: $e');
      if (mounted) {
        setState(() => _isLoadingSubjects = false);
      }
    }
  }

  Future<void> _pickFile() async {
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
      final fileSize = await file.length();
      if (fileSize == null) {
        throw const FormatException(
          'Không xác định được kích thước tệp đã chọn.',
        );
      }
      if (fileSize > FirebaseStorageService.maxFileSizeBytes) {
        throw const FormatException(
          'Kích thước tệp không được vượt quá 25 MB.',
        );
      }
      final bytes = await file.readAsBytes();

      final docId = widget.initialDocument?.id ?? const Uuid().v4();
      final user = FirebaseAuth.instance.currentUser;
      var finalUrl = '';

      setState(() {
        _pickedFileName = file.name;
        _transferError = null;
      });

      if (user != null && canUploadToCloud) {
        // Tải lên Firebase Cloud Storage với Progress Bar
        setState(() {
          _isUploading = true;
          _transferredBytes = 0;
          _totalBytes = bytes.lengthInBytes;
        });

        bool cloudAttemptFailed = false;
        try {
          final operation = FirebaseStorageService.createUpload(
            userId: user.uid,
            documentId: docId,
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
            documentId: docId,
            fileName: file.name,
            bytes: bytes,
          );
        }

        if (mounted) {
          setState(() {
            _isUploading = false;
            _fileUrlController.text = finalUrl;
          });
          openSnackbar(
            context,
            message: cloudAttemptFailed
                ? 'Đã lưu tệp đính kèm vào thiết bị (Cloud không khả dụng).'
                : 'Đã tải tệp lên Cloud Storage thành công!',
          );
        }
      } else {
        // Lưu tệp đính kèm cục bộ (offline / Desktop / chưa đăng nhập)
        final localUrl = FirebaseStorageService.saveLocalAttachment(
          documentId: docId,
          fileName: file.name,
          bytes: bytes,
        );
        setState(() {
          _fileUrlController.text = localUrl;
        });
        if (mounted) {
          openSnackbar(
            context,
            message: 'Đã đính kèm tệp "${file.name}" vào bài tập thành công!',
          );
        }
      }
    } on FirebaseException catch (error) {
      if (error.code != 'canceled') {
        _setTransferError(
          'Không thể tải tệp lên (${error.code}): '
          '${error.message ?? 'Firebase Storage từ chối yêu cầu.'}',
        );
      }
    } on FormatException catch (error) {
      _setTransferError(error.message);
    } catch (error) {
      _setTransferError('Lỗi chọn tệp: $error');
    } finally {
      if (mounted && _isUploading) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _setTransferError(String message) {
    if (!mounted) return;
    setState(() => _transferError = message);
    openSnackbar(context, message: message, isError: true);
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

  void _removeAttachedFile() {
    setState(() {
      _fileUrlController.clear();
      _pickedFileName = null;
      _transferError = null;
    });
    openSnackbar(context, message: 'Đã gỡ tệp đính kèm.');
  }

  @override
  void dispose() {
    _uploadSubscription?.cancel();
    _titleController.dispose();
    _notesController.dispose();
    _fileUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  (String, String)? _parseSubjectInput(String value) {
    final input = value.trim();
    final separator = RegExp(r'\s+[-–—]\s+').firstMatch(input);
    if (separator == null) return null;

    final code = input.substring(0, separator.start).trim();
    final name = input.substring(separator.end).trim();
    if (code.isEmpty || name.isEmpty) return null;
    return (code, name);
  }

  Future<String?> _resolveSubjectId() async {
    final selectedSubject = _availableSubjects.where(
      (s) => s.id == _selectedSubjectId,
    );
    if (selectedSubject.isNotEmpty &&
        _subjectInput.trim() ==
            '${selectedSubject.first.code} - ${selectedSubject.first.name}') {
      return selectedSubject.first.id;
    }

    final parsed = _parseSubjectInput(_subjectInput);
    if (parsed == null) {
      openSnackbar(
        context,
        message: 'Nhập môn theo định dạng MÃ - Tên môn, hoặc chọn một gợi ý.',
        isError: true,
      );
      return null;
    }

    final code = parsed.$1;
    final name = parsed.$2;
    final duplicateCode = _availableSubjects.where(
      (s) => s.code.toLowerCase() == code.toLowerCase(),
    );
    final duplicateName = _availableSubjects.where(
      (s) => s.name.toLowerCase() == name.toLowerCase(),
    );

    if (duplicateCode.isNotEmpty || duplicateName.isNotEmpty) {
      final existing = duplicateCode.isNotEmpty
          ? duplicateCode.first
          : duplicateName.first;
      if (existing.code.toLowerCase() == code.toLowerCase() &&
          existing.name.toLowerCase() == name.toLowerCase()) {
        return existing.id;
      }
      openSnackbar(
        context,
        message: 'Mã hoặc tên môn học đã được dùng cho một môn khác.',
        isError: true,
      );
      return null;
    }

    final subject = SubjectModel(
      id: const Uuid().v4(),
      name: name,
      code: code,
      colorValue: AppColors.primary.toARGB32(),
      iconName: 'school',
      createdDate: DateTime.now(),
    );
    await database.insertSubject(subject);
    if (mounted) {
      setState(() {
        _availableSubjects = [..._availableSubjects, subject];
        _selectedSubjectId = subject.id;
        _subjectInput = '${subject.code} - ${subject.name}';
      });
    }
    return subject.id;
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _selectedDeadline ?? now.add(const Duration(days: 3));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDeadline != null
            ? TimeOfDay.fromDateTime(_selectedDeadline!)
            : const TimeOfDay(hour: 23, minute: 59),
      );

      final combined = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime?.hour ?? 23,
        pickedTime?.minute ?? 59,
      );

      setState(() {
        _selectedDeadline = combined;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final subjectId = await _resolveSubjectId();
      if (subjectId == null) return;

      final rawTags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (isEditing) {
        // CẬP NHẬT TÀI LIỆU (Update)
        final updatedDoc = widget.initialDocument!.copyWith(
          title: _titleController.text.trim(),
          subjectId: subjectId,
          type: _selectedType,
          notes: _notesController.text.trim(),
          fileUrl: _fileUrlController.text.trim(),
          tags: rawTags,
          priority: _selectedPriority,
          isFavorite: _isFavorite,
          deadline: _selectedDeadline,
        );

        await DocumentService.updateDocument(updatedDoc);
        if (mounted) {
          openSnackbar(context, message: 'Đã cập nhật tài liệu thành công!');
          Navigator.pop(context, true);
        }
      } else {
        // TẠO MỚI TÀI LIỆU (Create)
        final newDoc = DocumentModel(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          subjectId: subjectId,
          type: _selectedType,
          notes: _notesController.text.trim(),
          fileUrl: _fileUrlController.text.trim(),
          tags: rawTags,
          status: DocumentStatus.pending,
          priority: _selectedPriority,
          isFavorite: _isFavorite,
          deadline: _selectedDeadline,
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        );

        await DocumentService.saveDocument(newDoc);
        if (mounted) {
          openSnackbar(context, message: 'Đã thêm tài liệu học tập mới!');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        openSnackbar(context, message: 'Lỗi: ${e.toString()}', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: isEditing ? 'Chỉnh sửa tài liệu' : 'Thêm tài liệu mới',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(isEditing ? 'Lưu' : 'Tạo mới'),
          ),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Chọn môn có sẵn từ gợi ý hoặc nhập mã và tên môn mới.
            Text(
              'Môn học / Học phần *',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Autocomplete<SubjectModel>(
              displayStringForOption: (subject) =>
                  '${subject.code} - ${subject.name}',
              initialValue: TextEditingValue(text: _subjectInput),
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                final matches = _availableSubjects.where(
                  (subject) =>
                      query.isEmpty ||
                      subject.code.toLowerCase().contains(query) ||
                      subject.name.toLowerCase().contains(query),
                );
                return matches.take(8);
              },
              onSelected: (subject) {
                _subjectInput = '${subject.code} - ${subject.name}';
                setState(() => _selectedSubjectId = subject.id);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) {
                        _subjectInput = value;
                        final selected = _availableSubjects.where(
                          (subject) =>
                              subject.id == _selectedSubjectId &&
                              value.trim() ==
                                  '${subject.code} - ${subject.name}',
                        );
                        if (selected.isEmpty) _selectedSubjectId = null;
                      },
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                      validator: (value) {
                        final selected = _availableSubjects.where(
                          (subject) =>
                              subject.id == _selectedSubjectId &&
                              value?.trim() ==
                                  '${subject.code} - ${subject.name}',
                        );
                        if (selected.isNotEmpty ||
                            _parseSubjectInput(value ?? '') != null) {
                          return null;
                        }
                        return 'Nhập theo định dạng MÃ - Tên môn.';
                      },
                      decoration: InputDecoration(
                        hintText: _isLoadingSubjects
                            ? 'Đang tải danh sách môn học...'
                            : 'Ví dụ: SWE302 - Kiến trúc phần mềm',
                        prefixIcon: const Icon(Icons.school_outlined),
                        suffixIcon: _isLoadingSubjects
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                      ),
                    );
                  },
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6, bottom: 12),
              child: Text(
                'Bấm vào ô để xem môn học gợi ý; chọn một môn hoặc nhập MÃ - Tên môn mới.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            // Phân loại tài liệu (Bài giảng / Bài tập / Tham khảo / Đề thi)
            const Text(
              'Phân loại tài liệu *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DocumentType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  avatar: Icon(
                    type.icon,
                    size: 16,
                    color: isSelected
                        ? type.color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  selectedColor: type.color.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? type.color : null,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? type.color
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedType = type;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Tiêu đề tài liệu
            CustomTextField(
              controller: _titleController,
              label: 'Tiêu đề tài liệu *',
              hint: 'Ví dụ: Bài tập lớn Kiến trúc Phần mềm Tuần 4',
              prefixIcon: Icons.title_rounded,
              validator: DocumentService.validateTitle,
            ),

            // ===================================================
            // MỤC UP FILE / ĐÍNH KÈM TỆP BÀI TẬP & TÀI LIỆU (VŨ HẢI ĐĂNG)
            // ===================================================
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: _selectedType == DocumentType.assignment
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: _selectedType == DocumentType.assignment ? 1.5 : 1,
                ),
              ),
              color: _selectedType == DocumentType.assignment
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _selectedType == DocumentType.assignment
                              ? Icons.assignment_turned_in_outlined
                              : Icons.cloud_upload_outlined,
                          size: 20,
                          color: _selectedType == DocumentType.assignment
                              ? AppColors.primary
                              : AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedType == DocumentType.assignment
                                ? 'Đính kèm tệp bài tập (Upload File)'
                                : 'Đính kèm tệp tài liệu',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (_selectedType == DocumentType.assignment)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Bài tập',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedType == DocumentType.assignment
                          ? 'Chọn tệp bài tập từ thiết bị để tải lên Cloud Storage (hỗ trợ nộp bài và đồng bộ).'
                          : 'Chọn tệp tài liệu (PDF, Word, Slide, Ảnh...) hoặc dán liên kết web.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),

                    // Hiển thị thanh tiến trình nếu đang upload
                    if (_isUploading) ...[
                      TransferProgressBar(
                        isUpload: true,
                        fileName: _pickedFileName,
                        transferredBytes: _transferredBytes,
                        totalBytes: _totalBytes,
                        onCancel: _cancelUpload,
                        errorMessage: _transferError,
                      ),
                    ] else if (_transferError != null) ...[
                      TransferProgressBar(
                        isUpload: true,
                        fileName: _pickedFileName,
                        transferredBytes: _transferredBytes,
                        totalBytes: _totalBytes,
                        errorMessage: _transferError,
                        onRetry: () => _pickFile(),
                      ),
                    ] else if (_fileUrlController.text.isNotEmpty) ...[
                      // Đã có file hoặc URL
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FirebaseStorageService.isStorageValue(
                                    _fileUrlController.text,
                                  )
                                  ? Icons.cloud_done_rounded
                                  : (_fileUrlController.text.startsWith('http')
                                        ? Icons.link_rounded
                                        : Icons.insert_drive_file_rounded),
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFileName ??
                                        FirebaseStorageService.fileNameFromPath(
                                          _fileUrlController.text,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  CloudSyncBadge(
                                    fileUrl: _fileUrlController.text,
                                    compact: true,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.file_upload_outlined,
                                size: 20,
                              ),
                              tooltip: 'Chọn tệp khác',
                              onPressed: _pickFile,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: AppColors.error,
                              ),
                              tooltip: 'Gỡ tệp',
                              onPressed: _removeAttachedFile,
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Chưa có file: Nút chọn file
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file_rounded, size: 20),
                          label: Text(
                            _selectedType == DocumentType.assignment
                                ? 'Chọn tệp bài tập để tải lên'
                                : 'Chọn tệp tải lên từ thiết bị',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Toggle dán liên kết web trực tiếp
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showCustomUrlInput = !_showCustomUrlInput;
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showCustomUrlInput
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _showCustomUrlInput
                                    ? 'Ẩn ô dán liên kết URL / Google Drive'
                                    : 'Hoặc dán liên kết Web / Google Drive trực tiếp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_showCustomUrlInput) ...[
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _fileUrlController,
                        label: 'Liên kết tệp / URL web',
                        hint: 'https://drive.google.com/... hoặc link tài liệu',
                        prefixIcon: Icons.link_rounded,
                        validator: DocumentService.validateUrl,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Nếu là bài tập hoặc đề thi: Chọn Hạn nộp (Deadline)
            if (_selectedType == DocumentType.assignment ||
                _selectedType == DocumentType.exam) ...[
              const Text(
                'Thời hạn hoàn thành (Deadline)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDeadline,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDeadline != null
                              ? DocumentFormatters.formatDateTime(
                                  _selectedDeadline,
                                )
                              : 'Chưa đặt hạn nộp (Bấm để chọn)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDeadline != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_selectedDeadline != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedDeadline = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Thẻ phân loại (Tags)
            CustomTextField(
              controller: _tagsController,
              label: 'Thẻ phân loại (Tags, phân cách bằng dấu phẩy)',
              hint: 'Ví dụ: Slide, Chương 2, Đồ án, Nộp gấp',
              prefixIcon: Icons.label_outline_rounded,
            ),

            // Mức độ ưu tiên
            const Text(
              'Mức độ ưu tiên',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PriorityLevel>(
              segments: const [
                ButtonSegment(value: PriorityLevel.low, label: Text('Thấp')),
                ButtonSegment(
                  value: PriorityLevel.medium,
                  label: Text('Bình thường'),
                ),
                ButtonSegment(
                  value: PriorityLevel.high,
                  label: Text('Cao / Gấp'),
                ),
              ],
              selected: {_selectedPriority},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedPriority = set.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Ghi chú tóm tắt
            CustomTextField(
              controller: _notesController,
              label: 'Ghi chú & Tóm tắt nội dung',
              hint: 'Ghi chú nội dung trọng tâm cần ghi nhớ...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 4,
            ),

            // Đánh dấu yêu thích / Quan trọng
            SwitchListTile(
              title: const Text(
                'Đánh dấu tài liệu quan trọng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Ghim hoặc gắn sao để xem nhanh tại trang chủ',
              ),
              value: _isFavorite,
              activeThumbColor: AppColors.warning,
              onChanged: (val) {
                setState(() {
                  _isFavorite = val;
                });
              },
              secondary: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: _isFavorite
                    ? AppColors.warning
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
