import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../database/databaseGlobal.dart';
import '../struct/models/document_models.dart';
import '../widgets/framework/page_framework.dart';

class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  final User user;
  final Future<void> Function() onSignOut;

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Chưa thiết lập tên hiển thị';
    final providerNames = user.providerData
        .map((provider) => provider.providerId)
        .toSet()
        .join(', ');

    return PageFramework(
      title: 'Trang cá nhân',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: user.photoURL?.isNotEmpty != true
                        ? null
                        : NetworkImage(user.photoURL!),
                    child: user.photoURL?.isNotEmpty != true
                        ? const Icon(Icons.person_rounded, size: 44)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user.email?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(user.email!, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin cá nhân',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ProfileInfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Tên hiển thị',
                    value: displayName,
                  ),
                  _ProfileInfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: user.email ?? 'Chưa cung cấp',
                  ),
                  _ProfileInfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Email xác thực',
                    value: user.emailVerified ? 'Đã xác thực' : 'Chưa xác thực',
                  ),
                  _ProfileInfoRow(
                    icon: Icons.login_rounded,
                    label: 'Phương thức đăng nhập',
                    value: providerNames.isEmpty ? 'Google' : providerNames,
                  ),
                  _ProfileInfoRow(
                    icon: Icons.fingerprint_rounded,
                    label: 'Mã tài khoản',
                    value: user.uid,
                  ),
                  if (user.metadata.creationTime != null)
                    _ProfileInfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Ngày tạo tài khoản',
                      value: _formatDate(user.metadata.creationTime!),
                    ),
                  if (user.metadata.lastSignInTime != null)
                    _ProfileInfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Đăng nhập gần nhất',
                      value: _formatDate(user.metadata.lastSignInTime!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tài liệu của bạn',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<DocumentModel>>(
                    future: database.getAllDocuments(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Không thể tải thống kê: ${snapshot.error}');
                      }
                      if (!snapshot.hasData) {
                        return const LinearProgressIndicator();
                      }
                      final documents = snapshot.data!;
                      final personal = documents.where((doc) => !doc.isShared);
                      final shared = documents.where((doc) => doc.isShared);
                      return Column(
                        children: [
                          _ProfileInfoRow(
                            icon: Icons.lock_outline_rounded,
                            label: 'Tài liệu riêng',
                            value: '${personal.length}',
                          ),
                          _ProfileInfoRow(
                            icon: Icons.people_outline_rounded,
                            label: 'Tài liệu dùng chung',
                            value: '${shared.length}',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tài liệu riêng chỉ hiển thị trong phạm vi tài khoản này. '
                    'Tài liệu dùng chung có thể được mọi tài khoản xem. '
                    'SQLite hiện lưu dữ liệu trên thiết bị này, chưa đồng bộ '
                    'giữa các thiết bị.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
          if (_isSigningOut) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: SelectableText(value, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
