import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../struct/google_auth_service.dart';
import '../widgets/framework/page_framework.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isBusy = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await GoogleAuthService.instance.signInWithGoogle();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message ?? error.code);
    } on GoogleSignInException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.description ?? error.code.name);
      }
    } on StateError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await GoogleAuthService.instance.signOut();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message ?? error.code);
    } on GoogleSignInException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.description ?? error.code.name);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleAuthService.instance.isConfigured) {
      return PageFramework(
        title: 'Tài khoản Firebase',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Đăng nhập Firebase hiện hỗ trợ Android, iOS và Web.'),
          ),
        ),
      );
    }

    return PageFramework(
      title: 'Tài khoản Firebase',
      body: StreamBuilder<User?>(
        stream: GoogleAuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể đọc trạng thái đăng nhập: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user?.photoURL case final photoUrl?)
                      CircleAvatar(
                        radius: 38,
                        backgroundImage: NetworkImage(photoUrl),
                      )
                    else
                      const CircleAvatar(
                        radius: 38,
                        child: Icon(Icons.person_outline, size: 38),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      user?.displayName ?? 'Chưa đăng nhập',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (user?.email case final email?)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(email, textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: user == null
                          ? FilledButton.icon(
                              onPressed: _isBusy ? null : _signIn,
                              icon: _isBusy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: const Text('Đăng nhập bằng Google'),
                            )
                          : OutlinedButton.icon(
                              onPressed: _isBusy ? null : _signOut,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Đăng xuất'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
