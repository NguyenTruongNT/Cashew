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

  @override
  void initState() {
    super.initState();
    _connectivity = widget.connectivity ?? Connectivity();
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _hasNetwork = true;
      return;
    }
    unawaited(_checkConnectivity());
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectivity,
      onError: (Object error) {
        if (mounted) setState(() => _error = error);
      },
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectivity(results);
    } catch (error) {
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
    final label = _error != null
        ? 'Không xác định được mạng'
        : _hasNetwork == null
        ? 'Đang kiểm tra mạng'
        : _hasNetwork!
        ? 'Có kết nối mạng'
        : 'Ngoại tuyến';
    final color = _error != null
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
            icon: _hasNetwork == false
                ? Icons.cloud_off_rounded
                : Icons.wifi_rounded,
            label: label,
            color: color,
            tooltip: _error == null
                ? 'Trạng thái kết nối mạng của thiết bị'
                : 'Không thể đọc trạng thái mạng: $_error',
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
      child: Chip(
        avatar: Icon(icon, size: 16, color: color),
        label: Text(label),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        labelStyle: TextStyle(color: color),
      ),
    );
  }
}
