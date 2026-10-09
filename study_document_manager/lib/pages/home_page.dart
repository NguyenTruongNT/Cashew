import 'dart:async';

import 'package:flutter/material.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';
import '../struct/models/document_models.dart';
import '../widgets/document_card.dart';
import '../widgets/framework/page_framework.dart';
import '../widgets/sync_status_banner.dart';
import 'account_page.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';
import 'document_list_page.dart';
import 'document_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, SubjectModel> _subjects = {};
  StreamSubscription<List<SubjectModel>>? _subjectsSubscription;

  @override
  void initState() {
    super.initState();
    _subjects = {for (final subject in database.cachedSubjects) subject.id: subject};
    _subjectsSubscription = database.watchAllSubjects.listen((subjects) {
      if (!mounted) return;
      setState(() {
        _subjects = {for (final subject in subjects) subject.id: subject};
      });
    });
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  void _openDocument(DocumentModel document) {
    pushRoute(context, DocumentDetailPage(documentId: document.id));
  }

  Widget _documentCard(DocumentModel document) {
    return DocumentCard(
      document: document,
      subject: _subjects[document.subjectId],
      onTap: () => _openDocument(document),
      onFavoriteToggle: document.isShared
          ? null
          : () => DocumentService.toggleFavorite(document),
      onStatusToggle: document.isShared
          ? null
          : () => DocumentService.toggleStatus(document),
      onEdit: document.isShared
          ? null
          : () => pushRoute(
                context,
                AddEditDocumentPage(initialDocument: document),
              ),
      onDelete: document.isShared
          ? null
          : () => DocumentService.deleteDocument(document.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: 'Quản lý tài liệu học tập',
      showBackButton: false,
      actions: [
        IconButton(
          onPressed: () => pushRoute(context, const AccountPage()),
          tooltip: 'Tài khoản Firebase',
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          onPressed: () => pushRoute(context, const DocumentSearchPage()),
          tooltip: 'Tìm kiếm',
          icon: const Icon(Icons.search_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => pushRoute(context, const AddEditDocumentPage()),
        tooltip: 'Thêm tài liệu',
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<DocumentModel>>(
        stream: database.watchAllDocuments,
        initialData: database.cachedDocuments,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải tài liệu: ${snapshot.error}'));
          }
          final documents = snapshot.data ?? const <DocumentModel>[];
          final stats = DocumentStats.fromList(documents);
          final pending = documents
              .where(
                (document) =>
                    document.type == DocumentType.assignment &&
                    document.status != DocumentStatus.completed,
              )
              .toList()
            ..sort((a, b) {
              if (a.deadline == null) return 1;
              if (b.deadline == null) return -1;
              return a.deadline!.compareTo(b.deadline!);
            });
          final recent = List<DocumentModel>.from(documents)
            ..sort((a, b) => b.updatedDate.compareTo(a.updatedDate));

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              const SyncStatusBanner(),
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.bannerGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng quan học kỳ',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${stats.totalDocuments} tài liệu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _Metric(
                          label: 'Môn học',
                          value: '${_subjects.length}',
                          icon: Icons.school_outlined,
                        ),
                        _Metric(
                          label: 'Bài tập chờ',
                          value: '${stats.pendingAssignments}',
                          icon: Icons.assignment_outlined,
                        ),
                        _Metric(
                          label: 'Yêu thích',
                          value: '${stats.favoriteCount}',
                          icon: Icons.star_outline_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_subjects.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Môn học',
                  onViewAll: () => pushRoute(context, const DocumentListPage()),
                ),
                SizedBox(
                  height: 116,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: _subjects.values
                        .map(
                          (subject) => SizedBox(
                            width: 210,
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => pushRoute(
                                  context,
                                  DocumentListPage(
                                    initialSubjectId: subject.id,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        subject.code,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(color: subject.color),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        subject.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (pending.isNotEmpty) ...[
                const _SectionHeader(title: 'Bài tập chưa hoàn thành'),
                ...pending.take(3).map(_documentCard),
              ],
              _SectionHeader(
                title: 'Tài liệu gần đây',
                onViewAll: () => pushRoute(context, const DocumentListPage()),
              ),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('Chưa có tài liệu. Thêm tài liệu để bắt đầu.')),
                )
              else
                ...recent.take(5).map(_documentCard),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        Text('$value $label', style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (onViewAll != null)
            TextButton(onPressed: onViewAll, child: const Text('Xem tất cả')),
        ],
      ),
    );
  }
}
