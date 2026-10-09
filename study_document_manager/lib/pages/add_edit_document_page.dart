import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/formatters.dart';
import '../struct/google_auth_service.dart';
import '../struct/models/document_models.dart';
import '../widgets/framework/page_framework.dart';

class AddEditDocumentPage extends StatefulWidget {
  const AddEditDocumentPage({
    super.key,
    this.initialDocument,
    this.defaultSubjectId,
  });

  final DocumentModel? initialDocument;
  final String? defaultSubjectId;

  @override
  State<AddEditDocumentPage> createState() => _AddEditDocumentPageState();
}

class _AddEditDocumentPageState extends State<AddEditDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subjectController;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _fileUrlController;
  late final TextEditingController _tagsController;

  List<SubjectModel> _subjects = [];
  String? _subjectId;
  late DocumentType _type;
  late PriorityLevel _priority;
  late bool _isFavorite;
  DateTime? _deadline;
  String? _storagePath;
  PlatformFile? _selectedFile;
  double? _uploadProgress;
  bool _loadingSubjects = true;
  bool _saving = false;

  bool get _isEditing => widget.initialDocument != null;

  @override
  void initState() {
    super.initState();
    final document = widget.initialDocument;
    _subjectId = document?.subjectId ?? widget.defaultSubjectId;
    _subjectController = TextEditingController();
    _titleController = TextEditingController(text: document?.title ?? '');
    _notesController = TextEditingController(text: document?.notes ?? '');
    _fileUrlController = TextEditingController(text: document?.fileUrl ?? '');
    _tagsController = TextEditingController(text: document?.tags.join(', ') ?? '');
    _type = document?.type ?? DocumentType.lecture;
    _priority = document?.priority ?? PriorityLevel.medium;
    _isFavorite = document?.isFavorite ?? false;
    _deadline = document?.deadline;
    _storagePath = document?.storagePath;
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await database.getAllSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        final selected = subjects.where((subject) => subject.id == _subjectId);
        if (selected.isNotEmpty) {
          _subjectController.text =
              '${selected.first.code} - ${selected.first.name}';
        }
        _loadingSubjects = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingSubjects = false);
      openSnackbar(
        context,
        message: 'Không thể tải danh sách môn học: $error',
        isError: true,
      );
    }
  }

  (String, String)? _parseSubject(String value) {
    final separator = RegExp(r'\s+[-–—]\s+').firstMatch(value.trim());
    if (separator == null) return null;
    final code = value.trim().substring(0, separator.start).trim();
    final name = value.trim().substring(separator.end).trim();
    return code.isEmpty || name.isEmpty ? null : (code, name);
  }

  Future<String?> _resolveSubjectId() async {
    final selected = _subjects.where((subject) => subject.id == _subjectId);
    if (selected.isNotEmpty &&
        _subjectController.text.trim() ==
            '${selected.first.code} - ${selected.first.name}') {
      return selected.first.id;
    }

    final parsed = _parseSubject(_subjectController.text);
    if (parsed == null) {
      openSnackbar(
        context,
        message: 'Nhập môn theo định dạng MÃ - Tên môn.',
        isError: true,
      );
      return null;
    }
    final duplicate = _subjects.where(
      (subject) =>
          subject.code.toLowerCase() == parsed.$1.toLowerCase() ||
          subject.name.toLowerCase() == parsed.$2.toLowerCase(),
    );
    if (duplicate.isNotEmpty) {
      final existing = duplicate.first;
      if (existing.code.toLowerCase() == parsed.$1.toLowerCase() &&
          existing.name.toLowerCase() == parsed.$2.toLowerCase()) {
        return existing.id;
      }
      openSnackbar(
        context,
        message: 'Mã hoặc tên môn học đã được dùng cho môn khác.',
        isError: true,
      );
      return null;
    }

    final subject = SubjectModel(
      id: const Uuid().v4(),
      name: parsed.$2,
      code: parsed.$1,
      colorValue: AppColors.primary.toARGB32(),
      iconName: 'school',
      createdDate: DateTime.now(),
    );
    await database.insertSubject(subject);
    _subjects = [..._subjects, subject];
    _subjectId = subject.id;
    return subject.id;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
        ],
      );
      if (result.isEmpty || !mounted) return;
      final file = result.single;
      final size = await file.length();
      if (size == null) {
        throw const FormatException('Không xác định được dung lượng tệp.');
      }
      if (size > FirebaseStorageService.maxFileSizeBytes) {
        throw const FormatException('Tệp vượt quá giới hạn 20 MiB.');
      }
      setState(() => _selectedFile = file);
    } catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể chọn tệp: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _deadline == null
          ? const TimeOfDay(hour: 23, minute: 59)
          : TimeOfDay.fromDateTime(_deadline!),
    );
    if (!mounted) return;
    setState(() {
      _deadline = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      );
    });
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _uploadProgress = null;
    });

    String? uploadedPath;
    try {
      final subjectId = await _resolveSubjectId();
      if (subjectId == null || !mounted) return;
      final documentId = widget.initialDocument?.id ?? const Uuid().v4();
      final selectedFile = _selectedFile;
      List<int>? bytes;
      if (selectedFile != null) {
        if (!GoogleAuthService.instance.isConfigured ||
            GoogleAuthService.instance.currentUser == null) {
          throw StateError(
            'Đăng nhập Google trên Android hoặc Web trước khi tải tệp lên Firebase.',
          );
        }
        bytes = await selectedFile.readAsBytes();
        uploadedPath = await FirebaseStorageService.instance.uploadDocument(
          file: selectedFile,
          documentId: documentId,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );
        _storagePath = uploadedPath;
      }

      final now = DateTime.now();
      final document = widget.initialDocument == null
          ? DocumentModel(
              id: documentId,
              title: _titleController.text.trim(),
              subjectId: subjectId,
              type: _type,
              notes: _notesController.text.trim(),
              fileUrl: _fileUrlController.text.trim(),
              storagePath: _storagePath,
              tags: _tagsController.text
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList(),
              priority: _priority,
              isFavorite: _isFavorite,
              deadline: _deadline,
              createdDate: now,
              updatedDate: now,
            )
          : widget.initialDocument!.copyWith(
              title: _titleController.text.trim(),
              subjectId: subjectId,
              type: _type,
              notes: _notesController.text.trim(),
              fileUrl: _fileUrlController.text.trim(),
              storagePath: _storagePath,
              tags: _tagsController.text
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList(),
              priority: _priority,
              isFavorite: _isFavorite,
              deadline: _deadline,
              updatedDate: now,
            );
      try {
        if (_isEditing) {
          await DocumentService.updateDocument(
            document,
            fileBytes: bytes,
            fileName: selectedFile?.name,
            fileAlreadyUploaded: uploadedPath != null,
          );
        } else {
          await DocumentService.saveDocument(
            document,
            fileBytes: bytes,
            fileName: selectedFile?.name,
            fileAlreadyUploaded: uploadedPath != null,
          );
        }
      } catch (error) {
        if (uploadedPath != null) {
          try {
            await FirebaseStorageService.instance.delete(uploadedPath);
          } catch (cleanupError) {
            throw StateError(
              'Không lưu được metadata ($error); cũng không thể xóa tệp vừa tải lên ($cleanupError).',
            );
          }
        }
        rethrow;
      }

      final oldPath = widget.initialDocument?.storagePath;
      if (oldPath != null && oldPath != _storagePath && uploadedPath != null) {
        await FirebaseStorageService.instance.delete(oldPath);
      }
      if (mounted) {
        openSnackbar(
          context,
          message: _isEditing
              ? 'Đã cập nhật tài liệu.'
              : 'Đã thêm tài liệu.',
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        openSnackbar(context, message: 'Không thể lưu tài liệu: $error', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _fileUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: _isEditing ? 'Chỉnh sửa tài liệu' : 'Thêm tài liệu',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_isEditing ? 'Lưu' : 'Tạo mới'),
          ),
        ),
      ],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Autocomplete<SubjectModel>(
              displayStringForOption: (subject) =>
                  '${subject.code} - ${subject.name}',
              initialValue: TextEditingValue(text: _subjectController.text),
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                return _subjects.where(
                  (subject) =>
                      query.isEmpty ||
                      subject.code.toLowerCase().contains(query) ||
                      subject.name.toLowerCase().contains(query),
                );
              },
              onSelected: (subject) {
                _subjectId = subject.id;
                _subjectController.text =
                    '${subject.code} - ${subject.name}';
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                _subjectController.value = controller.value;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (value) {
                    _subjectController.text = value;
                    final selected = _subjects.where(
                      (subject) =>
                          subject.id == _subjectId &&
                          value == '${subject.code} - ${subject.name}',
                    );
                    if (selected.isEmpty) _subjectId = null;
                  },
                  onFieldSubmitted: (_) => onSubmitted(),
                  validator: (value) =>
                      _parseSubject(value ?? '') == null &&
                          !_subjects.any(
                            (subject) =>
                                subject.id == _subjectId &&
                                '${subject.code} - ${subject.name}' ==
                                    value?.trim(),
                          )
                      ? 'Nhập theo định dạng MÃ - Tên môn.'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Môn học / Học phần *',
                    hintText: _loadingSubjects
                        ? 'Đang tải môn học...'
                        : 'Ví dụ: SWE302 - Kiến trúc phần mềm',
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DocumentType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại tài liệu'),
              items: DocumentType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              validator: DocumentService.validateTitle,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề tài liệu *',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fileUrlController,
              validator: DocumentService.validateUrl,
              decoration: const InputDecoration(
                labelText: 'Liên kết tài liệu (tùy chọn)',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickFile,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                _selectedFile?.name ??
                    (_storagePath == null
                        ? 'Chọn tệp tải lên Firebase'
                        : 'Thay tệp Firebase hiện tại'),
              ),
            ),
            if (_uploadProgress case final progress?) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              Text('Đang tải lên ${(progress * 100).round()}%'),
            ],
            if (_storagePath != null && _selectedFile == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Tệp hiện tại: ${FirebaseStorageService.fileNameFromPath(_storagePath!)}',
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Thẻ phân loại',
                hintText: 'Ví dụ: Flutter, bài tập, tham khảo',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<PriorityLevel>(
              segments: const [
                ButtonSegment(value: PriorityLevel.low, label: Text('Thấp')),
                ButtonSegment(
                  value: PriorityLevel.medium,
                  label: Text('Bình thường'),
                ),
                ButtonSegment(value: PriorityLevel.high, label: Text('Cao')),
              ],
              selected: {_priority},
              onSelectionChanged: (values) =>
                  setState(() => _priority = values.first),
            ),
            if (_type == DocumentType.assignment ||
                _type == DocumentType.exam) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDeadline,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _deadline == null
                      ? 'Đặt hạn hoàn thành'
                      : DocumentFormatters.formatDateTime(_deadline),
                ),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tài liệu quan trọng'),
              value: _isFavorite,
              onChanged: (value) => setState(() => _isFavorite = value),
            ),
          ],
        ),
      ),
    );
  }
}
