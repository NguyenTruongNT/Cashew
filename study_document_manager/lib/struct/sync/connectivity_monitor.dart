// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG ĐỒNG BỘ: THEO DÕI KẾT NỐI MẠNG (MONITOR)]
// File: lib/struct/sync/connectivity_monitor.dart
// Mô tả: Trừu tượng hóa khả năng phát hiện trạng thái mạng để đồng bộ
// tự động khi "mạng trở lại". Kèm bản điều khiển thủ công (ManualConnectivityMonitor)
// phục vụ kiểm thử và demo (bật/tắt mạng theo ý muốn).
//
// Ghi chú: Để dùng nguồn mạng thật trên thiết bị, chỉ cần implement interface
// này bằng package connectivity_plus (không bắt buộc cho task này).
// =====================================================================

import 'dart:async';

/// Theo dõi trạng thái kết nối mạng của thiết bị.
abstract class ConnectivityMonitor {
  /// Thiết bị đang online hay không.
  bool get isOnline;

  /// Stream phát sự thay đổi trạng thái mạng (true = online).
  Stream<bool> get onStatusChange;

  /// Bắt đầu lắng nghe.
  Future<void> start();

  /// Dừng lắng nghe và giải phóng tài nguyên.
  Future<void> dispose();
}

/// Bản điều khiển thủ công: dùng trong Unit Test và demo offline/online.
class ManualConnectivityMonitor implements ConnectivityMonitor {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _online;

  ManualConnectivityMonitor({bool initiallyOnline = true}) : _online = initiallyOnline;

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  /// Bật/tắt mạng theo ý muốn (mô phỏng mất mạng / mạng trở lại).
  void setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    _controller.add(value);
  }

  void goOffline() => setOnline(false);

  void goOnline() => setOnline(true);

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}