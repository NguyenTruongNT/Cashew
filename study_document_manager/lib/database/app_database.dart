import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../struct/models/document_models.dart';
import 'tables.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG DỮ LIỆU: BỘ ĐIỀU KHIỂN CƠ SỞ DỮ LIỆU (DATABASE ENGINE & DAO)]
// File: lib/database/app_database.dart
// Mô tả: Quản lý kết nối SQLite, khởi tạo Schema, cung cấp các phương thức
// DAO (Thêm, Sửa, Xóa, Truy vấn, Tìm kiếm) và luồng dữ liệu phản ứng (Reactive Stream)
// tương tự pattern watchAll() trong kiến trúc Cashew.
// Hỗ trợ chế độ In-Memory Fallback tự động khi chạy trên trình duyệt Web (Chrome).
// =====================================================================

class AppDatabase {
  Database? _db;
  bool _useMemoryFallback = false;
  final List<SubjectModel> _memorySubjects = [];
  final List<DocumentModel> _memoryDocuments = [];

  // StreamController để phát tín hiệu cập nhật tự động (Reactive Stream)
  final _documentsStreamController = StreamController<List<DocumentModel>>.broadcast();
  final _subjectsStreamController = StreamController<List<SubjectModel>>.broadcast();

  Stream<List<DocumentModel>> get watchAllDocuments => _documentsStreamController.stream;
  Stream<List<SubjectModel>> get watchAllSubjects => _subjectsStreamController.stream;

  /// Khởi tạo và mở cơ sở dữ liệu
  Future<void> init({bool isInMemory = false}) async {
    if (kIsWeb) {
      // Trên Web Chrome: Thử dùng WebAssembly không cần Web Worker
      try {
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
        final path = isInMemory ? inMemoryDatabasePath : 'cashew_study_docs.db';
        _db = await openDatabase(
          path,
          version: 2,
          onCreate: (db, version) async {
            await db.execute(SubjectTable.createTableSql);
            await db.execute(DocumentTable.createTableSql);
            await _seedDefaultData(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute(
                'ALTER TABLE ${DocumentTable.tableName} '
                'ADD COLUMN ${DocumentTable.colStoragePath} TEXT',
              );
            }
          },
        );
      } catch (e) {
        debugPrint('[Cashew AppDatabase] Web SQLite không khả dụng trên trình duyệt này, tự động kích hoạt bộ nhớ In-Memory Fallback: $e');
        _useMemoryFallback = true;
        _seedMemoryFallbackData();
      }
    } else {
      // Hỗ trợ Desktop (Windows, Linux, macOS) và môi trường UnitTest
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      String path;
      if (isInMemory) {
        path = inMemoryDatabasePath;
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        path = p.join(docsDir.path, 'cashew_study_docs.db');
      }

      _db = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute(SubjectTable.createTableSql);
          await db.execute(DocumentTable.createTableSql);
          await _seedDefaultData(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE ${DocumentTable.tableName} '
              'ADD COLUMN ${DocumentTable.colStoragePath} TEXT',
            );
          }
        },
      );
    }

    // Kích hoạt việc đẩy dữ liệu ban đầu vào Streams
    await notifyDocumentsChanged();
    await notifySubjectsChanged();
  }

  /// Nạp dữ liệu mẫu ban đầu vào SQLite Database
  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now();

    final defaultSubjects = _buildInitialSubjects(now);
    for (final s in defaultSubjects) {
      await db.insert(SubjectTable.tableName, s.toMap());
    }

    final defaultDocs = _buildInitialDocuments(now);
    for (final doc in defaultDocs) {
      await db.insert(DocumentTable.tableName, doc.toMap());
    }
  }

  /// Nạp dữ liệu mẫu vào bộ nhớ In-Memory khi chạy Web Fallback
  void _seedMemoryFallbackData() {
    final now = DateTime.now();
    _memorySubjects.clear();
    _memorySubjects.addAll(_buildInitialSubjects(now));
    _memoryDocuments.clear();
    _memoryDocuments.addAll(_buildInitialDocuments(now));
  }

  List<SubjectModel> _buildInitialSubjects(DateTime now) {
    return [
      SubjectModel(
        id: 'sub_swe',
        name: 'Kiến trúc & Thiết kế Phần mềm',
        code: 'SWE302',
        colorValue: 0xFF1E88E5,
        iconName: 'architecture',
        createdDate: now,
      ),
      SubjectModel(
        id: 'sub_mob',
        name: 'Lập trình Thiết bị Di động',
        code: 'MOB401',
        colorValue: 0xFF43A047,
        iconName: 'phone_android',
        createdDate: now,
      ),
      SubjectModel(
        id: 'sub_dsa',
        name: 'Cấu trúc Dữ liệu & Giải thuật',
        code: 'DSA201',
        colorValue: 0xFFFB8C00,
        iconName: 'account_tree',
        createdDate: now,
      ),
    ];
  }

  List<DocumentModel> _buildInitialDocuments(DateTime now) {
    return [
      DocumentModel(
        id: 'doc_1',
        title: 'Slide Bài giảng Chương 3: Phân tầng Kiến trúc Cashew',
        subjectId: 'sub_swe',
        type: DocumentType.lecture,
        notes: 'Nắm vững phân tách Presentation, Struct, Database Layer và nguyên tắc Reactive Streams.',
        fileUrl: 'https://docs.cashew-architecture.edu.vn/chapter3-cashew-pattern.pdf',
        tags: ['Cashew', 'Slide', 'Kiến trúc', 'Layered'],
        status: DocumentStatus.completed,
        priority: PriorityLevel.high,
        isFavorite: true,
        createdDate: now.subtract(const Duration(days: 3)),
        updatedDate: now.subtract(const Duration(days: 3)),
      ),
      DocumentModel(
        id: 'doc_2',
        title: 'Bài tập Lớn TH1: Triển khai Ứng dụng Quản lý Tài liệu',
        subjectId: 'sub_mob',
        type: DocumentType.assignment,
        notes: 'Yêu cầu đáp ứng đủ 5 checklist: Phân tích, Phân lớp Cashew, CRUD & Search, Unit test, Đóng gói.',
        fileUrl: 'https://classroom.google.com/c/assignment-th1-cashew',
        tags: ['TH1', 'Flutter', 'Bài tập lớn', 'Báo cáo'],
        status: DocumentStatus.inProgress,
        priority: PriorityLevel.high,
        isFavorite: true,
        deadline: now.add(const Duration(days: 5)),
        createdDate: now.subtract(const Duration(days: 1)),
        updatedDate: now,
      ),
      DocumentModel(
        id: 'doc_3',
        title: 'Giáo trình Tham khảo: Clean Architecture & SQLite Drift',
        subjectId: 'sub_swe',
        type: DocumentType.reference,
        notes: 'Sách tham khảo mở rộng về kỹ thuật tối ưu truy vấn và phân tách độc lập giữa các lớp.',
        fileUrl: 'https://drift.simonbinder.eu/docs/getting-started/',
        tags: ['Tham khảo', 'Drift', 'SQLite'],
        status: DocumentStatus.pending,
        priority: PriorityLevel.medium,
        isFavorite: false,
        createdDate: now.subtract(const Duration(days: 5)),
        updatedDate: now.subtract(const Duration(days: 5)),
      ),
      DocumentModel(
        id: 'doc_4',
        title: 'Đề cương Ôn thi Cuối kỳ môn Cấu trúc Dữ liệu',
        subjectId: 'sub_dsa',
        type: DocumentType.exam,
        notes: 'Trọng tâm các thuật toán đồ thị Dijkstra, Cây nhị phân tìm kiếm AVL và Quy hoạch động.',
        fileUrl: 'assets/docs/dsa_final_exam_review.pdf',
        tags: ['Đề thi', 'Ôn tập', 'DSA'],
        status: DocumentStatus.pending,
        priority: PriorityLevel.high,
        isFavorite: false,
        deadline: now.add(const Duration(days: 12)),
        createdDate: now.subtract(const Duration(days: 2)),
        updatedDate: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  Database get db {
    if (_db == null) {
      throw StateError('Cơ sở dữ liệu chưa được khởi tạo. Hãy gọi AppDatabase.init() trước.');
    }
    return _db!;
  }

  // ===================================================================
  // CÁC THAO TÁC CỐT LÕI (CRUD OPERATIONS) CHO TÀI LIỆU HỌC TẬP
  // ===================================================================

  /// [CHỨC NĂNG 1] Thêm tài liệu mới (Create)
  Future<int> insertDocument(DocumentModel document) async {
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == document.id);
      if (index >= 0) {
        _memoryDocuments[index] = document;
      } else {
        _memoryDocuments.insert(0, document);
      }
      await notifyDocumentsChanged();
      return 1;
    }

    final result = await db.insert(
      DocumentTable.tableName,
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// [CHỨC NĂNG 2] Cập nhật tài liệu (Update)
  Future<int> updateDocument(DocumentModel document) async {
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == document.id);
      if (index >= 0) {
        _memoryDocuments[index] = document;
        await notifyDocumentsChanged();
        return 1;
      }
      return 0;
    }

    final result = await db.update(
      DocumentTable.tableName,
      document.toMap(),
      where: '${DocumentTable.colId} = ?',
      whereArgs: [document.id],
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// [CHỨC NĂNG 3] Xóa tài liệu theo ID (Delete)
  Future<int> deleteDocument(String id) async {
    if (_useMemoryFallback) {
      _memoryDocuments.removeWhere((d) => d.id == id);
      await notifyDocumentsChanged();
      return 1;
    }

    final result = await db.delete(
      DocumentTable.tableName,
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// Lấy chi tiết tài liệu theo ID
  Future<DocumentModel?> getDocumentById(String id) async {
    if (_useMemoryFallback) {
      final matches = _memoryDocuments.where((d) => d.id == id);
      return matches.isEmpty ? null : matches.first;
    }

    final results = await db.query(
      DocumentTable.tableName,
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return DocumentModel.fromMap(results.first);
  }

  /// Lấy toàn bộ danh sách tài liệu
  Future<List<DocumentModel>> getAllDocuments() async {
    if (_useMemoryFallback) {
      final list = List<DocumentModel>.from(_memoryDocuments);
      list.sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }

    final results = await db.query(
      DocumentTable.tableName,
      orderBy: '${DocumentTable.colUpdatedDate} DESC',
    );
    return results.map((row) => DocumentModel.fromMap(row)).toList();
  }

  /// [CHỨC NĂNG 4] Tìm kiếm tài liệu học tập theo từ khóa, môn học, phân loại
  Future<List<DocumentModel>> searchDocuments({
    String query = '',
    String? subjectId,
    DocumentType? type,
    bool? onlyFavorite,
  }) async {
    if (_useMemoryFallback) {
      var list = List<DocumentModel>.from(_memoryDocuments);
      final trimmed = query.trim().toLowerCase();
      if (trimmed.isNotEmpty) {
        list = list.where((d) {
          final mTitle = d.title.toLowerCase().contains(trimmed);
          final mNotes = d.notes.toLowerCase().contains(trimmed);
          final mTags = d.tags.any((t) => t.toLowerCase().contains(trimmed));
          return mTitle || mNotes || mTags;
        }).toList();
      }
      if (subjectId != null && subjectId.isNotEmpty) {
        list = list.where((d) => d.subjectId == subjectId).toList();
      }
      if (type != null) {
        list = list.where((d) => d.type == type).toList();
      }
      if (onlyFavorite == true) {
        list = list.where((d) => d.isFavorite).toList();
      }
      list.sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
      return list;
    }

    final conditions = <String>[];
    final args = <dynamic>[];

    final trimmed = query.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      conditions.add(
        '(${DocumentTable.colTitle} LIKE ? OR ${DocumentTable.colNotes} LIKE ? OR ${DocumentTable.colTags} LIKE ?)',
      );
      args.addAll(['%$trimmed%', '%$trimmed%', '%$trimmed%']);
    }

    if (subjectId != null && subjectId.isNotEmpty) {
      conditions.add('${DocumentTable.colSubjectId} = ?');
      args.add(subjectId);
    }

    if (type != null) {
      conditions.add('${DocumentTable.colType} = ?');
      args.add(type.nameString);
    }

    if (onlyFavorite == true) {
      conditions.add('${DocumentTable.colIsFavorite} = 1');
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final results = await db.query(
      DocumentTable.tableName,
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: '${DocumentTable.colUpdatedDate} DESC',
    );

    return results.map((row) => DocumentModel.fromMap(row)).toList();
  }

  // ===================================================================
  // CÁC THAO TÁC CHO MÔN HỌC (SUBJECTS)
  // ===================================================================

  Future<int> insertSubject(SubjectModel subject) async {
    if (_useMemoryFallback) {
      final index = _memorySubjects.indexWhere((s) => s.id == subject.id);
      if (index >= 0) {
        _memorySubjects[index] = subject;
      } else {
        _memorySubjects.add(subject);
      }
      await notifySubjectsChanged();
      return 1;
    }

    final result = await db.insert(
      SubjectTable.tableName,
      subject.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await notifySubjectsChanged();
    return result;
  }

  Future<List<SubjectModel>> getAllSubjects() async {
    if (_useMemoryFallback) {
      final list = List<SubjectModel>.from(_memorySubjects);
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }

    final results = await db.query(
      SubjectTable.tableName,
      orderBy: '${SubjectTable.colName} ASC',
    );
    return results.map((row) => SubjectModel.fromMap(row)).toList();
  }

  Future<SubjectModel?> getSubjectById(String id) async {
    if (_useMemoryFallback) {
      final matches = _memorySubjects.where((s) => s.id == id);
      return matches.isEmpty ? null : matches.first;
    }

    final results = await db.query(
      SubjectTable.tableName,
      where: '${SubjectTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SubjectModel.fromMap(results.first);
  }

  // ===================================================================
  // PHẢN ỨNG DỮ LIỆU THEO PHONG CÁCH CASHEW (REACTIVE NOTIFIERS)
  // ===================================================================

  Future<void> notifyDocumentsChanged() async {
    final all = await getAllDocuments();
    if (!_documentsStreamController.isClosed) {
      _documentsStreamController.add(all);
    }
  }

  Future<void> notifySubjectsChanged() async {
    final all = await getAllSubjects();
    if (!_subjectsStreamController.isClosed) {
      _subjectsStreamController.add(all);
    }
  }

  Future<void> close() async {
    await _documentsStreamController.close();
    await _subjectsStreamController.close();
    await _db?.close();
  }
}
