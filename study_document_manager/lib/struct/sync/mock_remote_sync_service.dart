// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: CLOUD GIẢ LẬP + MÔ PHỎNG MẠNG YẾU]
// File: lib/struct/sync/mock_remote_sync_service.dart
// Mô tả: Cài đặt RemoteSyncService lưu trong bộ nhớ, có khả năng mô phỏng
// độ trễ, băng thông giới hạn và mất gói — phục vụ unit test và kịch bản
// kiểm thử hiệu năng truyền tải khi mạng yếu.
// =====================================================================

import 'dart:convert';
import 'dart:math';

import 'remote_sync_service.dart';

/// Hồ sơ mạng mô phỏng (latency, băng thông, tỷ lệ mất gói).
class NetworkProfile {
  /// Độ trễ mỗi thao tác (round-trip).
  final Duration latency;

  /// Băng thông tối đa (byte/giây). 0 = không giới hạn.
  final int bandwidthBytesPerSecond;

  /// Tỷ lệ mất gói [0.0, 1.0].
  final double packetLossRate;

  const NetworkProfile({
    this.latency = Duration.zero,
    this.bandwidthBytesPerSecond = 0,
    this.packetLossRate = 0,
  });

  bool get unlimitedBandwidth => bandwidthBytesPerSecond <= 0;

  /// Mạng lý tưởng (không trễ, không giới hạn).
  static const NetworkProfile ideal = NetworkProfile();

  /// Wi-Fi ổn định.
  static const NetworkProfile wifi = NetworkProfile(
    latency: Duration(milliseconds: 20),
    bandwidthBytesPerSecond: 2 * 1024 * 1024,
    packetLossRate: 0,
  );

  /// 3G yếu: trễ cao, băng thông thấp, có mất gói.
  static const NetworkProfile weak3G = NetworkProfile(
    latency: Duration(milliseconds: 350),
    bandwidthBytesPerSecond: 64 * 1024,
    packetLossRate: 0.03,
  );

  /// Mạng rất yếu / chập chờn (2G-like).
  static const NetworkProfile veryWeak = NetworkProfile(
    latency: Duration(milliseconds: 800),
    bandwidthBytesPerSecond: 16 * 1024,
    packetLossRate: 0.10,
  );

  String get label {
    if (this == ideal) return 'Lý tưởng';
    if (this == wifi) return 'Wi-Fi';
    if (this == weak3G) return '3G yếu';
    if (this == veryWeak) return 'Rất yếu (2G)';
    return 'Tùy chỉnh';
  }

  @override
  bool operator ==(Object other) =>
      other is NetworkProfile &&
      other.latency == latency &&
      other.bandwidthBytesPerSecond == bandwidthBytesPerSecond &&
      other.packetLossRate == packetLossRate;

  @override
  int get hashCode =>
      Object.hash(latency, bandwidthBytesPerSecond, packetLossRate);
}

/// Cloud giả lập lưu trong bộ nhớ + mô phỏng đặc tính mạng.
class MockRemoteSyncService implements RemoteSyncService {
  MockRemoteSyncService({
    this.profile = NetworkProfile.ideal,
    this.online = true,
    int seed = 42,
  }) : _random = Random(seed);

  /// Hồ sơ mạng đang áp dụng.
  NetworkProfile profile;

  /// Trạng thái kết nối mô phỏng.
  bool online;

  final Random _random;

  /// ownerId -> documentId -> RemoteDocument
  final Map<String, Map<String, RemoteDocument>> _documents = {};

  /// storagePath -> bytes
  final Map<String, List<int>> _files = {};

  // ---------------------- Thống kê phục vụ kiểm thử ----------------------
  int transferCount = 0;
  int totalBytesTransferred = 0;
  int failedTransfers = 0;
  int _forcedFailures = 0;

  /// Ép [count] thao tác kế tiếp thất bại (để test retry/queue).
  void forceNextFailures(int count) => _forcedFailures = count;

  void resetStats() {
    transferCount = 0;
    totalBytesTransferred = 0;
    failedTransfers = 0;
  }

  // ---------------------- Mô phỏng đường truyền ----------------------
  Future<void> _simulateTransfer(int bytes) async {
    if (!online) {
      failedTransfers++;
      throw const RemoteNetworkException();
    }
    if (_forcedFailures > 0) {
      _forcedFailures--;
      failedTransfers++;
      throw const RemoteNetworkException('Mô phỏng lỗi tạm thời');
    }
    if (profile.packetLossRate > 0 && _random.nextDouble() < profile.packetLossRate) {
      failedTransfers++;
      throw const RemoteNetworkException('Mất gói (packet loss)');
    }
    transferCount++;
    totalBytesTransferred += bytes;

    if (profile.latency > Duration.zero) {
      await Future<void>.delayed(profile.latency);
    }
    if (!profile.unlimitedBandwidth && bytes > 0) {
      final millis =
          (bytes * 1000 / profile.bandwidthBytesPerSecond).ceil();
      await Future<void>.delayed(Duration(milliseconds: millis));
    }
  }

  // ---------------------- Dữ liệu mồi cho kiểm thử ----------------------
  void seedDocument(RemoteDocument document) {
    _documents
        .putIfAbsent(document.ownerId, () => {})[document.id] = document;
  }

  void seedFile(String storagePath, List<int> bytes) {
    _files[storagePath] = List<int>.from(bytes);
  }

  RemoteDocument? documentAt(String ownerId, String documentId) =>
      _documents[ownerId]?[documentId];

  bool hasFile(String storagePath) => _files.containsKey(storagePath);

  List<int>? fileAt(String storagePath) => _files[storagePath];

  int documentCount(String ownerId) => _documents[ownerId]?.length ?? 0;

  // ---------------------- Triển khai interface ----------------------

  @override
  Future<bool> ping() async {
    if (!online) return false;
    if (profile.latency > Duration.zero) {
      await Future<void>.delayed(profile.latency);
    }
    return true;
  }

  @override
  Future<DateTime> serverTime() => Future.value(DateTime.now());

  @override
  Future<List<RemoteDocument>> pullChanges({
    required String ownerId,
    DateTime? since,
  }) async {
    await _simulateTransfer(0);
    final all = _documents[ownerId]?.values.toList() ?? <RemoteDocument>[];
    final changes = all
        .where((d) => since == null || d.updatedAt.isAfter(since))
        .toList()
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return changes;
  }

  @override
  Future<RemoteDocument> pushDocument(RemoteDocument document) async {
    await _simulateTransfer(jsonEncode(document.data).length);

    final existing = _documents[document.ownerId]?[document.id];
    if (existing != null && existing.version > document.version) {
      throw RemoteConflictException(existing);
    }

    final canonical = document.copyWith(
      version: document.version,
      updatedAt: DateTime.now(),
      isDeleted: document.isDeleted,
    );
    _documents.putIfAbsent(document.ownerId, () => {})[document.id] = canonical;
    return canonical;
  }

  @override
  Future<void> deleteRemoteDocument({
    required String ownerId,
    required String documentId,
    String? storagePath,
  }) async {
    await _simulateTransfer(0);
    final existing = _documents[ownerId]?[documentId];
    if (existing != null) {
      // Giữ tombstone để các thiết bị khác nhận biết thao tác xóa qua Pull.
      _documents[ownerId]![documentId] = existing.copyWith(
        isDeleted: true,
        version: existing.version + 1,
        updatedAt: DateTime.now(),
      );
    }
    if (storagePath != null) {
      _files.remove(storagePath);
    }
  }

  @override
  Future<String> uploadFile({
    required String ownerId,
    required String documentId,
    required String fileName,
    required List<int> bytes,
    void Function(double progress)? onProgress,
  }) async {
    await _simulateTransfer(bytes.length);
    final storagePath = 'mock://$ownerId/$documentId/$fileName';
    _files[storagePath] = List<int>.from(bytes);
    onProgress?.call(1.0);
    return storagePath;
  }

  @override
  Future<List<int>?> downloadFile({
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = _files[storagePath];
    if (bytes == null) {
      await _simulateTransfer(0);
      return null;
    }
    await _simulateTransfer(bytes.length);
    onProgress?.call(1.0);
    return List<int>.from(bytes);
  }

  @override
  Future<void> deleteFile({required String storagePath}) async {
    await _simulateTransfer(0);
    _files.remove(storagePath);
  }
}
