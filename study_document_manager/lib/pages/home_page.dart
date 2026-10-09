import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../colors.dart';
import '../database/databaseGlobal.dart';
import '../functions.dart';
import '../struct/document_service.dart';

import '../struct/google_auth_service.dart';

import '../struct/models/document_models.dart';
import '../widgets/document_card.dart';
import '../widgets/framework/page_framework.dart';
import '../widgets/cloud/account_menu_button.dart';
import '../widgets/cloud/cloud_status_strip.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';
import 'document_list_page.dart';
import 'document_search_page.dart';
import 'account_page.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN CHỨC NĂNG: TRANG CHỦ DASHBOARD]
// File: lib/pages/home_page.dart
// Mô tả:
// - Hiển thị Dashboard quản lý tài liệu.
// - Tổng hợp thống kê tài liệu và môn học.
// - Hiển thị bài tập cần nộp và tài liệu gần đây.
// - Cung cấp chức năng tìm kiếm, thêm tài liệu và đăng xuất.
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

    _subjectsSubscription = database.watchAllSubjects.listen((
      List<SubjectModel> subjects,
    ) {
      if (!mounted) {
        return;

      }

      setState(() {
        _subjectMap = <String, SubjectModel>{
          for (final SubjectModel subject in subjects) subject.id: subject,
        };
      });
    });
  }

  @override
  void dispose() {
    _subjectsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSubjects() async {

    final List<SubjectModel> subjects = await database.getAllSubjects();

    if (!mounted) {
      return;
    }

    setState(() {
      _subjectMap = <String, SubjectModel>{
        for (final SubjectModel subject in subjects) subject.id: subject,
      };
    });
  }

  Future<void> _confirmSignOut() async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.logout_rounded),
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) {
      return;
    }

    try {
      await GoogleAuthService.instance.signOut();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đăng xuất: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      title: 'Quản Lý Tài Liệu Học Tập',
      showBackButton: false,
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => pushRoute(context, const AccountPage()),
          tooltip: 'Tài khoản Firebase',
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            pushRoute(context, const DocumentSearchPage());
          },
          tooltip: 'Tìm kiếm tài liệu',
        ),

        IconButton(
          icon: const Icon(Icons.logout_rounded),
          onPressed: _confirmSignOut,
          tooltip: 'Đăng xuất',
        ),

      ],
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          pushRoute(context, const AddEditDocumentPage());
        },
        tooltip: 'Thêm tài liệu mới',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: StreamBuilder<List<DocumentModel>>(
        stream: database.watchAllDocuments,

        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<DocumentModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<DocumentModel> allDocuments =
                  snapshot.data ?? <DocumentModel>[];

              final DocumentStats stats = DocumentStats.fromList(allDocuments);

              // Danh sách bài tập chưa hoàn thành.
              final List<DocumentModel> pendingAssignments =
                  allDocuments
                      .where(
                        (DocumentModel document) =>
                            document.type == DocumentType.assignment &&
                            document.status != DocumentStatus.completed,
                      )
                      .toList()
                    ..sort((DocumentModel first, DocumentModel second) {
                      if (first.deadline == null && second.deadline == null) {
                        return 0;
                      }

                      if (first.deadline == null) {
                        return 1;
                      }

                      if (second.deadline == null) {
                        return -1;
                      }

                      return first.deadline!.compareTo(second.deadline!);
                    });

              // Danh sách tài liệu cập nhật gần đây.
              final List<DocumentModel> recentDocuments =
                  List<DocumentModel>.from(allDocuments)
                    ..sort((DocumentModel first, DocumentModel second) {
                      return second.updatedDate.compareTo(first.updatedDate);
                    });

              final List<DocumentModel> topRecent = recentDocuments
                  .take(5)
                  .toList();

              return ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: <Widget>[
                  // =======================================================
                  // 1. BANNER THỐNG KÊ TỔNG QUAN
                  // =======================================================
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.bannerGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),

                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
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
                          children: <Widget>[
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
                        LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                final bool compact = constraints.maxWidth < 420;

                                final double metricWidth = compact
                                    ? (constraints.maxWidth - 12) / 2
                                    : (constraints.maxWidth - 36) / 4;

                                return Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  runAlignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: <Widget>[
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

                  // =======================================================
                  // 2. PHÍM TẮT TRUY CẬP NHANH
                  // =======================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            onPressed: () {
                              pushRoute(context, const DocumentListPage());
                            },
                            icon: const Icon(
                              Icons.folder_shared_rounded,
                              size: 18,
                            ),
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            onPressed: () {
                              pushRoute(
                                context,
                                const DocumentListPage(
                                  initialType: DocumentType.assignment,
                                ),
                              );
                            },
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

                  // =======================================================
                  // 3. DANH SÁCH MÔN HỌC
                  // =======================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Môn học',

                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            pushRoute(context, const DocumentListPage());
                          },
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _subjectMap.values.map((SubjectModel subject) {
                        final int documentCount = allDocuments
                            .where(
                              (DocumentModel document) =>
                                  document.subjectId == subject.id,
                            )
                            .length;

                        return InkWell(
                          onTap: () {
                            pushRoute(
                              context,
                              DocumentListPage(initialSubjectId: subject.id),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: subject.color.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.school_rounded,
                                    color: subject.color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  subject.code,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: subject.color,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subject.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$documentCount tài liệu',
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

                  // =======================================================
                  // 4. BÀI TẬP CẦN NỘP GẤP
                  // =======================================================
                  if (pendingAssignments.isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: <Widget>[
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
                    ...pendingAssignments.take(3).map((DocumentModel document) {
                      final SubjectModel? subject =
                          _subjectMap[document.subjectId];

                      return DocumentCard(
                        document: document,
                        subject: subject,
                        onTap: () {
                          pushRoute(
                            context,
                            DocumentDetailPage(documentId: document.id),
                          );
                        },
                        onFavoriteToggle: () {
                          DocumentService.toggleFavorite(document);
                        },
                        onStatusToggle: () {
                          DocumentService.toggleStatus(document);
                        },
                        onEdit: () {
                          pushRoute(
                            context,
                            AddEditDocumentPage(initialDocument: document),
                          );
                        },
                        onDelete: () {
                          DocumentService.deleteDocument(document.id);
                        },
                      );
                    }),
                    const SizedBox(height: 20),
                  ],

                  // =======================================================
                  // 5. TÀI LIỆU GẦN ĐÂY
                  // =======================================================
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Tài liệu học tập gần đây',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            pushRoute(context, const DocumentListPage());
                          },
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),

                  ),
                  if (topRecent.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Chưa có tài liệu nào. '
                          'Bấm nút (+) để thêm!',
                        ),
                      ),
                    )
                  else
                    ...topRecent.map((DocumentModel document) {
                      final SubjectModel? subject =
                          _subjectMap[document.subjectId];

                      return DocumentCard(
                        document: document,
                        subject: subject,
                        onTap: () {
                          pushRoute(
                            context,
                            DocumentDetailPage(documentId: document.id),
                          );
                        },
                        onFavoriteToggle: () {
                          DocumentService.toggleFavorite(document);
                        },
                        onStatusToggle: () {
                          DocumentService.toggleStatus(document);
                        },
                        onEdit: () {
                          pushRoute(
                            context,
                            AddEditDocumentPage(initialDocument: document),
                          );
                        },
                        onDelete: () {
                          DocumentService.deleteDocument(document.id);
                        },
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
      children: <Widget>[
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
