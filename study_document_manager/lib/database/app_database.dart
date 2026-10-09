import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:uuid/uuid.dart';
import '../struct/models/document_models.dart';
import '../struct/sync/sync_models.dart';
import '../struct/sync/sync_status.dart';
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
  final List<DeleteLogEntry> _memoryDeleteLogs = [];
  final Map<String, String> _memorySyncMeta = {};
  final _uuid = Uuid();

  /// Phiên bản schema hiện tại (v2 bổ sung các cột/bảng phục vụ Offline Sync).
  static const int schemaVersion = 2;

  /// Mã thiết bị, dùng để phân biệt nguồn gốc tombstone khi đồng bộ.
  String deviceId = 'local-device';

  /// Khóa metadata lưu mốc thời gian kéo dữ liệu gần nhất.
  static const String metaKeyLastSyncAt = 'last_sync_at';

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
          version: schemaVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
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
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    // Kích hoạt việc đẩy dữ liệu ban đầu vào Streams
    await notifyDocumentsChanged();
    await notifySubjectsChanged();
  }

  /// Tạo toàn bộ schema ở phiên bản mới nhất (lần đầu cài đặt).
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(SubjectTable.createTableSql);
    await db.execute(DocumentTable.createTableSql);
    await db.execute(DeleteLogTable.createTableSql);
    await db.execute(SyncMetaTable.createTableSql);
    await _seedDefaultData(db);
  }

  /// Nâng cấp schema từ phiên bản cũ lên phiên bản hiện tại.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Bổ sung các cột Offline Sync cho bảng documents (giữ nguyên dữ liệu cũ).
      for (final sql in DocumentTable.syncColumnsSql) {
        await db.execute(sql);
      }
      await db.execute(DeleteLogTable.createTableSql);
      await db.execute(SyncMetaTable.createTableSql);
    }
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
  ///
  /// [markPending] = true (mặc định): đánh dấu tài liệu là `pendingCreate`
  /// để đưa vào hàng đợi đồng bộ Cloud. Truyền false khi ghi dữ liệu đến từ Cloud.
  Future<int> insertDocument(DocumentModel document, {bool markPending = true}) async {
    final effective = markPending
        ? document.copyWithSync(syncStatus: SyncStatus.pendingCreate)
        : document;

    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == effective.id);
      if (index >= 0) {
        _memoryDocuments[index] = effective;
      } else {
        _memoryDocuments.insert(0, effective);
      }
      await notifyDocumentsChanged();
      return 1;
    }

    final result = await db.insert(
      DocumentTable.tableName,
      effective.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// [CHỨC NĂNG 2] Cập nhật tài liệu (Update)
  ///
  /// [markPending] = true (mặc định): đánh dấu `pendingUpdate` để đồng bộ Cloud.
  Future<int> updateDocument(DocumentModel document, {bool markPending = true}) async {
    final effective = markPending
        ? document.copyWithSync(syncStatus: SyncStatus.pendingUpdate)
        : document;

    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == effective.id);
      if (index >= 0) {
        _memoryDocuments[index] = effective;
        await notifyDocumentsChanged();
        return 1;
      }
      return 0;
    }

    final result = await db.update(
      DocumentTable.tableName,
      effective.toMap(),
      where: '${DocumentTable.colId} = ?',
      whereArgs: [document.id],
    );
    await notifyDocumentsChanged();
    return result;
  }

  /// [CHỨC NĂNG 3] Xóa tài liệu theo ID (Delete)
  ///
  /// Ghi một tombstone vào `delete_logs` (trừ khi [recordTombstone] = false)
  /// để lệnh xóa được đẩy lên Cloud khi có mạng trở lại, tránh hồi sinh dữ liệu.
  Future<int> deleteDocument(String id, {bool recordTombstone = true}) async {
    if (recordTombstone) {
      final existing = await getDocumentById(id);
      if (existing != null) {
        await recordDeleteLog(
          DeleteLogEntry(
            id: _uuid.v4(),
            documentId: id,
            deletedAt: DateTime.now(),
            deviceId: deviceId,
            checksum: existing.checksum,
            synced: false,
          ),
        );
      }
    }

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

  /// Áp dụng tài liệu nhận từ Cloud: ghi đè và đánh dấu `synced`.
  Future<int> applyRemoteDocument(DocumentModel document, {int remoteVersion = 0}) async {
    final effective = document.copyWithSync(
      syncStatus: SyncStatus.synced,
      remoteVersion: remoteVersion,
      lastSyncedAt: DateTime.now(),
    );
    return insertDocument(effective, markPending: false);
  }

  /// Xóa tài liệu do Cloud báo xóa (không tạo tombstone mới).
  Future<int> applyRemoteDelete(String id) {
    return deleteDocument(id, recordTombstone: false);
  }

  /// Cập nhật riêng metadata tệp (checksum/kích thước/đường dẫn cache).
  Future<void> updateDocumentFileMetadata(
    String id, {
    String? checksum,
    int? fileSize,
    String? localFilePath,
  }) async {
    final values = <String, dynamic>{
      DocumentTable.colChecksum: ?checksum,
      DocumentTable.colFileSize: ?fileSize,
      DocumentTable.colLocalFilePath: ?localFilePath,
    };
    if (values.isEmpty) return;

    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == id);
      if (index >= 0) {
        _memoryDocuments[index] = _memoryDocuments[index].copyWithSync(
          checksum: checksum,
          fileSize: fileSize,
          localFilePath: localFilePath,
        );
        await notifyDocumentsChanged();
      }
      return;
    }

    await db.update(
      DocumentTable.tableName,
      values,
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
    );
    await notifyDocumentsChanged();
  }

  /// Đánh dấu tài liệu đã đồng bộ thành công (chỉ cập nhật trường sync,
  /// KHÔNG thay đổi `updated_date` để bảo toàn mốc Last-Write-Wins).
  Future<void> markDocumentSynced(
    String id, {
    int? remoteVersion,
    String? checksum,
    int? fileSize,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_useMemoryFallback) {
      final index = _memoryDocuments.indexWhere((d) => d.id == id);
      if (index >= 0) {
        _memoryDocuments[index] = _memoryDocuments[index].copyWithSync(
          syncStatus: SyncStatus.synced,
          remoteVersion: remoteVersion,
          checksum: checksum,
          fileSize: fileSize,
          lastSyncedAt: DateTime.now(),
        );
        await notifyDocumentsChanged();
      }
      return;
    }

    final values = <String, dynamic>{
      DocumentTable.colSyncStatus: SyncStatus.synced.nameString,
      DocumentTable.colLastSyncedAt: now,
      DocumentTable.colRemoteVersion: ?remoteVersion,
      DocumentTable.colChecksum: ?checksum,
      DocumentTable.colFileSize: ?fileSize,
    };
    await db.update(
      DocumentTable.tableName,
      values,
      where: '${DocumentTable.colId} = ?',
      whereArgs: [id],
    );
    await notifyDocumentsChanged();
  }

  /// Lấy danh sách tài liệu đang có thay đổi cục bộ chờ đẩy lên Cloud.
  Future<List<DocumentModel>> getPendingDocuments() async {
    final all = await getAllDocuments();
    return all.where((d) => d.isPendingSync && d.syncStatus != SyncStatus.pendingDelete).toList();
  }

  /// Lấy danh sách tài liệu có thay đổi cục bộ (bao gồm cả chờ xóa nếu có).
  Future<List<DocumentModel>> getPendingSyncDocuments() async {
    final all = await getAllDocuments();
    return all.where((d) => d.isPendingSync).toList();
  }

  /// Đếm nhanh số bản ghi đang chờ đồng bộ (tài liệu + tombstone xóa).
  Future<int> countPendingSyncChanges() async {
    final docs = await getPendingDocuments();
    final deletes = await getPendingDeleteLogs();
    return docs.length + deletes.length;
  }

  // ===================================================================
  // NHẬT KÝ XÓA (DELETE LOGS) - PHỤC VỤ ĐỒNG BỘ TOMBSTONE
  // ===================================================================

  /// Ghi một bản ghi nhật ký xóa vào bảng `delete_logs`.
  Future<void> recordDeleteLog(DeleteLogEntry entry) async {
    if (_useMemoryFallback) {
      final index = _memoryDeleteLogs.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        _memoryDeleteLogs[index] = entry;
      } else {
        _memoryDeleteLogs.add(entry);
      }
      return;
    }
    await db.insert(
      DeleteLogTable.tableName,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy toàn bộ nhật ký xóa.
  Future<List<DeleteLogEntry>> getAllDeleteLogs() async {
    if (_useMemoryFallback) {
      final list = List<DeleteLogEntry>.from(_memoryDeleteLogs);
      list.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return list;
    }
    final results = await db.query(
      DeleteLogTable.tableName,
      orderBy: '${DeleteLogTable.colDeletedAt} DESC',
    );
    return results.map((row) => DeleteLogEntry.fromMap(row)).toList();
  }

  /// Lấy các nhật ký xóa chưa được đẩy lên Cloud.
  Future<List<DeleteLogEntry>> getPendingDeleteLogs() async {
    if (_useMemoryFallback) {
      final list = _memoryDeleteLogs.where((e) => !e.synced).toList();
      list.sort((a, b) => a.deletedAt.compareTo(b.deletedAt));
      return list;
    }
    final results = await db.query(
      DeleteLogTable.tableName,
      where: '${DeleteLogTable.colSynced} = 0',
      orderBy: '${DeleteLogTable.colDeletedAt} ASC',
    );
    return results.map((row) => DeleteLogEntry.fromMap(row)).toList();
  }

  /// Đánh dấu một nhật ký xóa đã được Cloud xử lý.
  Future<void> markDeleteLogSynced(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_useMemoryFallback) {
      final index = _memoryDeleteLogs.indexWhere((e) => e.id == id);
      if (index >= 0) {
        _memoryDeleteLogs[index] = _memoryDeleteLogs[index].copyWith(
          synced: true,
          remotePurgedAt: DateTime.now(),
        );
      }
      return;
    }
    await db.update(
      DeleteLogTable.tableName,
      {
        DeleteLogTable.colSynced: 1,
        DeleteLogTable.colRemotePurgedAt: now,
      },
      where: '${DeleteLogTable.colId} = ?',
      whereArgs: [id],
    );
  }

  // ===================================================================
  // METADATA ĐỒNG BỘ (MỐC THỜI GIAN KÉO DỮ LIỆU GẦN NHẤT...)
  // ===================================================================

  Future<String?> getSyncMeta(String key) async {
    if (_useMemoryFallback) return _memorySyncMeta[key];
    final results = await db.query(
      SyncMetaTable.tableName,
      where: '${SyncMetaTable.colKey} = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first[SyncMetaTable.colValue] as String?;
  }

  Future<void> setSyncMeta(String key, String value) async {
    if (_useMemoryFallback) {
      _memorySyncMeta[key] = value;
      return;
    }
    await db.insert(
      SyncMetaTable.tableName,
      {SyncMetaTable.colKey: key, SyncMetaTable.colValue: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Mốc thời gian kéo dữ liệu (pull) gần nhất từ Cloud.
  Future<DateTime?> getLastSyncAt() async {
    final raw = await getSyncMeta(metaKeyLastSyncAt);
    if (raw == null) return null;
    final millis = int.tryParse(raw);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastSyncAt(DateTime time) {
    return setSyncMeta(metaKeyLastSyncAt, time.millisecondsSinceEpoch.toString());
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
