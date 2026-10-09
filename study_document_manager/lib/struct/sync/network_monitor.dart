// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: GIÁM SÁT KẾT NỐI MẠNG]
// File: lib/struct/sync/network_monitor.dart
// Mô tả: Phát hiện trạng thái Online/Offline. Bản Heartbeat dùng chính
// `RemoteSyncService.ping()` để kiểm tra khả năng tới Cloud (đáng tin hơn
// kiểm tra "có Wi-Fi" đơn thuần). Bản Manual phục vụ unit test.
// =====================================================================

import 'dart:async';

import 'remote_sync_service.dart';

/// Giao diện giám sát kết nối.
abstract class NetworkMonitor {
  bool get isOnline;
  Stream<bool> get onStatusChange;
  Future<bool> checkNow();
  void start();
  void dispose();
}

/// Giám sát bằng nhịp tim (heartbeat) gọi `ping()` định kỳ.
class HeartbeatNetworkMonitor implements NetworkMonitor {
  HeartbeatNetworkMonitor({
    required this.remote,
    this.interval = const Duration(seconds: 10),
  });

  final RemoteSyncService remote;
  final Duration interval;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  bool _online = true;
  bool _started = false;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  @override
  void start() {
    if (_started) return;
    _started = true;
    _timer = Timer.periodic(interval, (_) => checkNow());
    unawaited(checkNow());
  }

  @override
  Future<bool> checkNow() async {
    bool result;
    try {
      result = await remote.ping();
    } catch (_) {
      result = false;
    }
    _setOnline(result);
    return result;
  }

  void _setOnline(bool value) {
    if (value == _online) return;
    _online = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// Giám sát thủ công — cho phép test bật/tắt mạng tức thời.
class ManualNetworkMonitor implements NetworkMonitor {
  // The analyzer suggests an initializing formal, but named parameters
  // cannot start with an underscore, so a private named field cannot use one.
  // ignore: prefer_initializing_formals
  ManualNetworkMonitor({bool online = true}) : _online = online;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _online;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void setOnline(bool value) {
    if (value == _online) return;
    _online = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  Future<bool> checkNow() async => _online;

  @override
  void start() {}

  @override
  void dispose() {
    _controller.close();
  }
}
