import 'dart:async';

import 'package:flutter/material.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/models/document_models.dart';
import '../widgets/document_card.dart';
import '../widgets/framework/page_framework.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';
import 'document_list_page.dart';
import 'document_search_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: TRANG CHỦ DASHBOARD]
// File: lib/pages/home_page.dart
// Mô tả: Màn hình bảng điều khiển chính (Dashboard), tổng hợp thống kê số liệu,
// hiển thị danh sách môn học, bài tập cần nộp gấp và tài liệu xem gần đây.
// =====================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, SubjectModel> _subjectMap = {};
  StreamSubscription<List<SubjectModel>>? _subjectsSubscription;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
    _subjectsSubscription = database.watchAllSubjects.listen((subjects) {
      if (mounted) {
        setState(() {
          _subjectMap = {for (final subject in subjects) subject.id: subject};
        });
      }
    });
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final list = await database.getAllSubjects();
    if (mounted) {
      setState(() {
        _subjectMap = {for (final s in list) s.id: s};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: 'Quản Lý Tài Liệu Học Tập',
      showBackButton: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => pushRoute(context, const DocumentSearchPage()),
          tooltip: 'Tìm kiếm tài liệu',
        ),
      ],
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => pushRoute(context, const AddEditDocumentPage()),
        tooltip: 'Thêm tài liệu mới',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: StreamBuilder<List<DocumentModel>>(
        stream: database.watchAllDocuments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data ?? [];
          final stats = DocumentStats.fromList(allDocs);

          // Danh sách bài tập chưa hoàn thành (sắp xếp theo hạn chót gần nhất)
          final pendingAssignments =
              allDocs
                  .where(
                    (d) =>
                        d.type == DocumentType.assignment &&
                        d.status != DocumentStatus.completed,
                  )
                  .toList()
                ..sort((a, b) {
                  if (a.deadline == null && b.deadline == null) return 0;
                  if (a.deadline == null) return 1;
                  if (b.deadline == null) return -1;
                  return a.deadline!.compareTo(b.deadline!);
                });

          // Danh sách tài liệu cập nhật gần đây (lấy tối đa 5)
          final recentDocs = List<DocumentModel>.from(allDocs)
            ..sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
          final topRecent = recentDocs.take(5).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              // 1. BANNER THỐNG KÊ TỔNG QUAN PHONG CÁCH CASHEW
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.bannerGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng quan tài liệu học kỳ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${stats.totalDocuments} Tài liệu',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_subjectMap.length} Môn học',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    // 4 Thẻ thống kê con
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 420;
                        final metricWidth = compact
                            ? (constraints.maxWidth - 12) / 2
                            : (constraints.maxWidth - 36) / 4;
                        return Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runAlignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: metricWidth,
                              child: _buildMetricCol(
                                'Bài giảng',
                                stats.lectureCount.toString(),
                                Icons.slideshow_rounded,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _buildMetricCol(
                                'Bài tập',
                                stats.assignmentCount.toString(),
                                Icons.assignment_outlined,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _buildMetricCol(
                                'Chưa nộp',
                                stats.pendingAssignments.toString(),
                                Icons.warning_amber_rounded,
                                isAlert: stats.pendingAssignments > 0,
                              ),
                            ),
                            SizedBox(
                              width: metricWidth,
                              child: _buildMetricCol(
                                'Tham khảo',
                                stats.referenceCount.toString(),
                                Icons.menu_book_rounded,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 2. PHÍM TẮT TRUY CẬP NHANH (QUICK ACTIONS)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        onPressed: () =>
                            pushRoute(context, const DocumentListPage()),
                        icon: const Icon(Icons.folder_shared_rounded, size: 18),
                        label: const Text(
                          'Kho tài liệu',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        onPressed: () => pushRoute(
                          context,
                          const DocumentListPage(
                            initialType: DocumentType.assignment,
                          ),
                        ),
                        icon: const Icon(
                          Icons.task_alt_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        label: const Text(
                          'Bài tập cần làm',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. MÔN HỌC / HỌC PHẦN (SUBJECT LIST)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Môn học',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          pushRoute(context, const DocumentListPage()),
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _subjectMap.values.map((s) {
                    final docCountInSubject = allDocs
                        .where((d) => d.subjectId == s.id)
                        .length;
                    return InkWell(
                      onTap: () => pushRoute(
                        context,
                        DocumentListPage(initialSubjectId: s.id),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: s.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.school_rounded,
                                color: s.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.code,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: s.color,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$docCountInSubject tài liệu',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // 4. BÀI TẬP CẦN NỘP GẤP (URGENT ASSIGNMENTS)
              if (pendingAssignments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Bài tập cần nộp gấp',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${pendingAssignments.length} bài',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                ...pendingAssignments.take(3).map((doc) {
                  final sub = _subjectMap[doc.subjectId];
                  return DocumentCard(
                    document: doc,
                    subject: sub,
                    onTap: () => pushRoute(
                      context,
                      DocumentDetailPage(documentId: doc.id),
                    ),
                    onFavoriteToggle: () => DocumentService.toggleFavorite(doc),
                    onStatusToggle: () => DocumentService.toggleStatus(doc),
                    onEdit: () => pushRoute(
                      context,
                      AddEditDocumentPage(initialDocument: doc),
                    ),
                    onDelete: () => DocumentService.deleteDocument(doc.id),
                  );
                }),
                const SizedBox(height: 20),
              ],

              // 5. TÀI LIỆU GẦN ĐÂY (RECENT DOCUMENTS)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tài liệu học tập gần đây',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          pushRoute(context, const DocumentListPage()),
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
              ),
              if (topRecent.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Chưa có tài liệu nào. Bấm nút (+) để thêm!'),
                  ),
                )
              else
                ...topRecent.map((doc) {
                  final sub = _subjectMap[doc.subjectId];
                  return DocumentCard(
                    document: doc,
                    subject: sub,
                    onTap: () => pushRoute(
                      context,
                      DocumentDetailPage(documentId: doc.id),
                    ),
                    onFavoriteToggle: () => DocumentService.toggleFavorite(doc),
                    onStatusToggle: () => DocumentService.toggleStatus(doc),
                    onEdit: () => pushRoute(
                      context,
                      AddEditDocumentPage(initialDocument: doc),
                    ),
                    onDelete: () => DocumentService.deleteDocument(doc.id),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCol(
    String label,
    String value,
    IconData icon, {
    bool isAlert = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: isAlert ? Colors.yellowAccent : Colors.white,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isAlert ? Colors.yellowAccent : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
