import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../functions.dart';
import '../../pages/account_profile_page.dart';
import '../../struct/google_auth_service.dart';

class AccountMenuButton extends StatefulWidget {
  const AccountMenuButton({super.key});

  @override
  State<AccountMenuButton> createState() => _AccountMenuButtonState();
}

class _AccountMenuButtonState extends State<AccountMenuButton> {
  bool _isBusy = false;

  Future<void> _signIn() async {
    setState(() => _isBusy = true);
    try {
      await GoogleAuthService.instance.signInWithGoogle();
      if (!mounted) return;
      openSnackbar(context, message: 'Đăng nhập thành công.');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: _authErrorMessage(error.code, error.message),
          isError: true,
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: _authErrorMessage(error.code, error.message),
          isError: true,
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message:
              'Không thể đăng nhập Google (${error.code}): '
              '${error.message ?? 'Kiểm tra cấu hình OAuth của ứng dụng.'}',
          isError: true,
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Google Sign-In failed (${error.runtimeType}): $error\n$stackTrace',
      );
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể đăng nhập (${error.runtimeType}): $error',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _authErrorMessage(String code, String? message) {
    switch (code) {
      case 'operation-not-allowed':
      case 'auth/operation-not-allowed':
        return 'Google Sign-In chưa được bật trong Firebase Authentication '
            '(mã: $code).';
      case 'CONFIGURATION_NOT_FOUND':
      case 'configuration-not-found':
      case 'auth/configuration-not-found':
        return 'Firebase Authentication chưa được khởi tạo cho project '
            'cashew-study-docs-3afed. Mở Firebase Console > Authentication, '
            'chọn Get started, sau đó bật Google trong Sign-in method '
            '(mã: $code).';
      case 'unauthorized-domain':
      case 'auth/unauthorized-domain':
        return 'Tên miền hiện tại chưa được thêm vào Firebase Authentication > '
            'Authorized domains (mã: $code).';
      case 'popup-blocked':
      case 'auth/popup-blocked':
        return 'Trình duyệt đã chặn cửa sổ đăng nhập. Hãy cho phép popup rồi thử lại '
            '(mã: $code).';
      case 'network-request-failed':
      case 'auth/network-request-failed':
        return 'Không thể kết nối dịch vụ xác thực. Kiểm tra mạng rồi thử lại '
            '(mã: $code).';
      default:
        return 'Không thể đăng nhập ($code): '
            '${message ?? 'Firebase không trả về thông tin chi tiết.'}';
    }
  }

  Future<void> _signOut() async {
    setState(() => _isBusy = true);
    try {
      await GoogleAuthService.instance.signOut();
      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        openSnackbar(context, message: 'Đã đăng xuất.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể đăng xuất: ${error.message ?? error.code}',
          isError: true,
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        openSnackbar(
          context,
          message: 'Không thể đăng xuất Google: ${error.message ?? error.code}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openProfile(User user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountProfilePage(user: user, onSignOut: _signOut),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleAuthService.instance.isConfigured) {
      return IconButton(
        tooltip: 'Firebase không được hỗ trợ trên nền tảng này',
        onPressed: () => openSnackbar(
          context,
          message: 'Đăng nhập Firebase hiện được cấu hình cho Android và Web.',
        ),
        icon: const Icon(Icons.account_circle_outlined),
      );
    }
    return StreamBuilder<User?>(
      stream: GoogleAuthService.instance.authStateChanges,
      initialData: GoogleAuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return IconButton(
            tooltip: 'Không thể đọc trạng thái tài khoản',
            onPressed: () => openSnackbar(
              context,
              message: 'Lỗi xác thực: ${snapshot.error}',
              isError: true,
            ),
            icon: const Icon(Icons.account_circle_outlined),
          );
        }

        final user = snapshot.data;
        return PopupMenuButton<String>(
          tooltip: user == null
              ? 'Tài khoản'
              : 'Tài khoản ${user.displayName ?? user.email ?? ''}',
          enabled: !_isBusy,
          onSelected: (action) {
            if (action == 'profile' && user != null) {
              _openProfile(user);
            } else if (action == 'sign-in') {
              _signIn();
            } else if (action == 'sign-out') {
              _signOut();
            }
          },
          itemBuilder: (context) => [
            if (user != null) ...[
              PopupMenuItem<String>(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _accountIcon(user),
                  title: Text(
                    user.displayName?.isNotEmpty == true
                        ? user.displayName!
                        : 'Tài khoản Google',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    user.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_outline_rounded),
                  title: Text('Trang cá nhân'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'sign-out',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Đăng xuất'),
                ),
              ),
            ] else
              const PopupMenuItem<String>(
                value: 'sign-in',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.login_rounded),
                  title: Text('Đăng nhập bằng Google'),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _accountIcon(user),
          ),
        );
      },
    );
  }

  Widget _accountIcon(User? user) {
    final photoUrl = user?.photoURL;
    if (photoUrl == null || photoUrl.isEmpty) {
      return Icon(
        user == null
            ? Icons.account_circle_outlined
            : Icons.account_circle_rounded,
      );
    }

    return CircleAvatar(
      radius: 16,
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.account_circle_rounded, size: 28),
        ),
      ),
    );
  }
}
