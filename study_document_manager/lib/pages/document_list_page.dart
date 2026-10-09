import 'package:flutter/material.dart';
import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/models/document_models.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/document_card.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';
import 'document_search_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: DANH SÁCH TÀI LIỆU]
// File: lib/pages/document_list_page.dart
// Mô tả: Màn hình quản lý danh sách toàn bộ tài liệu học tập,
// sử dụng cơ chế phản ứng dữ liệu (Reactive StreamBuilder) của kiến trúc Cashew.
// =====================================================================

class DocumentListPage extends StatefulWidget {
  final String? initialSubjectId;
  final DocumentType? initialType;

  const DocumentListPage({
    super.key,
    this.initialSubjectId,
    this.initialType,
  });

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  late DocumentType? _selectedType;
  late String? _selectedSubjectId;
  DocumentSortOption _sortOption = DocumentSortOption.latestUpdated;
  bool _onlyFavorites = false;

  Map<String, SubjectModel> _subjectMap = {};

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedSubjectId = widget.initialSubjectId;
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final list = await database.getAllSubjects();
    if (mounted) {
      setState(() {
        _subjectMap = {for (final s in list) s.id: s};
      });
    }
  }

  void _onFavoriteToggle(DocumentModel doc) async {
    await DocumentService.toggleFavorite(doc);
  }

  void _onStatusToggle(DocumentModel doc) async {
    await DocumentService.toggleStatus(doc);
  }

  void _onEdit(DocumentModel doc) {
    pushRoute(context, AddEditDocumentPage(initialDocument: doc));
  }

  void _onDelete(DocumentModel doc) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDeleteDialog(
        documentTitle: doc.title,
        onConfirm: () async {
          await DocumentService.deleteDocument(doc.id);
          if (mounted) {
            openSnackbar(context, message: 'Đã xóa tài liệu!');
          }
        },
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Sắp xếp danh sách tài liệu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(),
              RadioListTile<DocumentSortOption>(
                title: const Text('Cập nhật mới nhất'),
                value: DocumentSortOption.latestUpdated,
                groupValue: _sortOption,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<DocumentSortOption>(
                title: const Text('Hạn nộp gần nhất (Ưu tiên nộp bài)'),
                value: DocumentSortOption.deadlineEarliest,
                groupValue: _sortOption,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<DocumentSortOption>(
                title: const Text('Mức độ ưu tiên cao nhất'),
                value: DocumentSortOption.priorityHighest,
                groupValue: _sortOption,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
              RadioListTile<DocumentSortOption>(
                title: const Text('Theo tên A - Z'),
                value: DocumentSortOption.titleAsc,
                groupValue: _sortOption,
                onChanged: (val) {
                  setState(() => _sortOption = val!);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: 'Quản lý tài liệu',
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => pushRoute(context, const DocumentSearchPage()),
          tooltip: 'Tìm kiếm',
        ),
        IconButton(
          icon: const Icon(Icons.sort_rounded),
          onPressed: _showSortDialog,
          tooltip: 'Sắp xếp',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => pushRoute(
          context,
          AddEditDocumentPage(defaultSubjectId: _selectedSubjectId),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm tài liệu'),
      ),
      body: Column(
        children: [
          // Bộ lọc phân loại nằm ngang
          FilterChipBar(
            selectedType: _selectedType,
            onSelected: (type) {
              setState(() => _selectedType = type);
            },
          ),

          // Lọc theo Môn học và Tài liệu quan trọng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        value: _selectedSubjectId,
                        hint: const Text('Tất cả môn học', style: TextStyle(fontSize: 12)),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả môn học', style: TextStyle(fontSize: 12)),
                          ),
                          ..._subjectMap.values.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text('[${s.code}] ${s.name}', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSubjectId = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Quan trọng', style: TextStyle(fontSize: 12)),
                  selected: _onlyFavorites,
                  avatar: Icon(
                    _onlyFavorites ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 16,
                    color: _onlyFavorites
                        ? AppColors.warning
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  selectedColor: AppColors.warning.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    setState(() => _onlyFavorites = val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Danh sách phản ứng theo Reactive Stream của Cashew
          Expanded(
            child: StreamBuilder<List<DocumentModel>>(
              stream: database.watchAllDocuments,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawList = snapshot.data ?? [];
                final filteredList = DocumentService.filterAndSort(
                  source: rawList,
                  typeFilter: _selectedType,
                  subjectIdFilter: _selectedSubjectId,
                  onlyFavorites: _onlyFavorites,
                  sortOption: _sortOption,
                );

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có tài liệu nào',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bấm "+ Thêm tài liệu" để bắt đầu lưu trữ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 4),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final doc = filteredList[index];
                    final sub = _subjectMap[doc.subjectId];
                    return DocumentCard(
                      document: doc,
                      subject: sub,
                      onTap: () => pushRoute(
                        context,
                        DocumentDetailPage(documentId: doc.id),
                      ),
                      onFavoriteToggle: () => _onFavoriteToggle(doc),
                      onStatusToggle: () => _onStatusToggle(doc),
                      onEdit: () => _onEdit(doc),
                      onDelete: () => _onDelete(doc),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
