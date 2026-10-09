import 'dart:async';
import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class CloudStatusStrip extends StatefulWidget {
  const CloudStatusStrip({super.key, this.connectivity});

  final Connectivity? connectivity;

  @override
  State<CloudStatusStrip> createState() => _CloudStatusStripState();
}

class _CloudStatusStripState extends State<CloudStatusStrip> {
  late final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool? _hasNetwork;
  Object? _error;

  bool get _isTestEnv {
    if (kIsWeb) return false;
    return Platform.environment.containsKey('FLUTTER_TEST');
  }

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivity ?? Connectivity();

    if (_isTestEnv && widget.connectivity == null) {
      _hasNetwork = true;
      return;
    }

    _checkConnectivity();
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivity,
        onError: (Object error) {
          if (mounted) setState(() => _error = error);
        },
      );
    } catch (_) {
      // Bỏ qua khi chạy trong môi trường chưa đăng ký platform channel
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => [ConnectivityResult.none],
      );
      _updateConnectivity(result);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _hasNetwork = results.any((result) => result != ConnectivityResult.none);
      _error = null;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final networkLabel = _error != null
        ? 'Không xác định được mạng'
        : _hasNetwork == null
        ? 'Đang kiểm tra mạng'
        : _hasNetwork!
        ? 'Có kết nối mạng'
        : 'Ngoại tuyến';
    final networkIcon = _error != null || _hasNetwork == false
        ? Icons.cloud_off_rounded
        : Icons.wifi_rounded;
    final networkColor = _error != null
        ? colors.error
        : _hasNetwork == false
        ? colors.tertiary
        : colors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusChip(
            icon: networkIcon,
            label: networkLabel,
            color: networkColor,
            tooltip: _error == null
                ? 'Trạng thái kết nối mạng của thiết bị'
                : 'Không đọc được trạng thái mạng: $_error',
          ),
          _StatusChip(
            icon: Icons.sync_disabled_rounded,
            label: 'Metadata chưa đồng bộ Cloud',
            color: colors.onSurfaceVariant,
            tooltip: 'Metadata hiện chỉ được lưu trong SQLite trên thiết bị.',
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: '$label. $tooltip',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
