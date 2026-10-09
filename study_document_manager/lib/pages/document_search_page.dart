import 'package:flutter/material.dart';
import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/models/document_models.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/document_card.dart';
import '../widgets/document_search_bar.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: TÌM KIẾM TÀI LIỆU]
// File: lib/pages/document_search_page.dart
// Mô tả: Màn hình Tìm kiếm tài liệu chuyên sâu theo Checklist 3. Cho phép
// tìm kiếm theo từ khóa (tiêu đề, ghi chú, thẻ tag) kết hợp bộ lọc môn học và loại tài liệu.
// =====================================================================

class DocumentSearchPage extends StatefulWidget {
  final String? initialQuery;

  const DocumentSearchPage({super.key, this.initialQuery});

  @override
  State<DocumentSearchPage> createState() => _DocumentSearchPageState();
}

class _DocumentSearchPageState extends State<DocumentSearchPage> {
  String _query = '';
  DocumentType? _typeFilter;
  String? _subjectFilter;
  bool _onlyFavorites = false;

  List<DocumentModel> _results = [];
  Map<String, SubjectModel> _subjectMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final subjects = await database.getAllSubjects();
    _subjectMap = {for (final s in subjects) s.id: s};
    await _performSearch();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);
    final docs = await database.searchDocuments(
      query: _query,
      subjectId: _subjectFilter,
      type: _typeFilter,
      onlyFavorite: _onlyFavorites,
    );

    if (mounted) {
      setState(() {
        _results = docs;
        _isLoading = false;
      });
    }
  }

  void _onFavoriteToggle(DocumentModel doc) async {
    await DocumentService.toggleFavorite(doc);
    await _performSearch();
  }

  void _onStatusToggle(DocumentModel doc) async {
    await DocumentService.toggleStatus(doc);
    await _performSearch();
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
            await _performSearch();
          }
        },
      ),
    );
  }

  void _onEdit(DocumentModel doc) async {
    final res = await pushRoute(
      context,
      AddEditDocumentPage(initialDocument: doc),
    );
    if (res == true) {
      await _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: 'Tìm kiếm tài liệu',
      body: Column(
        children: [
          // Thanh tìm kiếm Debounce
          DocumentSearchBar(
            controller: TextEditingController(text: _query)..selection = TextSelection.collapsed(offset: _query.length),
            hintText: 'Nhập tên tài liệu, ghi chú hoặc thẻ #tag...',
            onChanged: (val) {
              _query = val;
              _performSearch();
            },
            onClear: () {
              _query = '';
              _performSearch();
            },
          ),

          // Thanh lọc nhanh loại tài liệu
          FilterChipBar(
            selectedType: _typeFilter,
            onSelected: (type) {
              setState(() => _typeFilter = type);
              _performSearch();
            },
          ),

          // Bộ lọc nâng cao: Môn học và Yêu thích
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Chọn môn học
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
                        value: _subjectFilter,
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
                          setState(() => _subjectFilter = val);
                          _performSearch();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Lọc yêu thích
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
                    _performSearch();
                  },
                ),
              ],
            ),
          ),

          // Số lượng kết quả
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Tìm thấy ${_results.length} tài liệu phù hợp',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Danh sách kết quả
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Không tìm thấy tài liệu nào',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thử thay đổi từ khóa hoặc bộ lọc tìm kiếm',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final doc = _results[index];
                          final sub = _subjectMap[doc.subjectId];
                          return DocumentCard(
                            document: doc,
                            subject: sub,
                            onTap: () async {
                              final res = await pushRoute(
                                context,
                                DocumentDetailPage(documentId: doc.id),
                              );
                              if (res == true) _performSearch();
                            },
                            onFavoriteToggle: () => _onFavoriteToggle(doc),
                            onStatusToggle: () => _onStatusToggle(doc),
                            onEdit: () => _onEdit(doc),
                            onDelete: () => _onDelete(doc),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
