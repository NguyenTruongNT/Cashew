import 'package:flutter/material.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.displayName,
    required this.email,
    required this.photoUrl,
    required this.isSignedIn,
    required this.isBusy,
    required this.onSignIn,
    required this.onSignOut,
  });

  final String? displayName;
  final String? email;
  final String? photoUrl;
  final bool isSignedIn;
  final bool isBusy;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim();
    final userEmail = email?.trim();
    final effectiveName = name?.isNotEmpty == true
        ? name!
        : (userEmail?.isNotEmpty == true ? userEmail! : 'Tài khoản Google');
    final effectivePhotoUrl = photoUrl?.trim();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: ClipOval(
                child: effectivePhotoUrl?.isNotEmpty == true
                    ? Image.network(
                        effectivePhotoUrl!,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _fallbackAvatar(context),
                      )
                    : _fallbackAvatar(context),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              effectiveName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (userEmail?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                userEmail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isSignedIn
                  ? OutlinedButton.icon(
                      onPressed: isBusy ? null : onSignOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Đăng xuất'),
                    )
                  : FilledButton.icon(
                      onPressed: isBusy ? null : onSignIn,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Đăng nhập bằng Google'),
                    ),
            ),
            if (isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar(BuildContext context) => SizedBox(
    width: 76,
    height: 76,
    child: Icon(
      Icons.person_rounded,
      size: 42,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}
