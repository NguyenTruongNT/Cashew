import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_platform_support.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();


  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  bool get isConfigured => canUseFirebase;

  User? get currentUser => isConfigured ? _firebaseAuth.currentUser : null;

  Stream<User?> get authStateChanges =>
      isConfigured ? _firebaseAuth.authStateChanges() : const Stream.empty();

  bool get isSignedIn => currentUser != null;

  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized || kIsWeb) {
      return;
    }

    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    if (!isConfigured) {
      throw StateError('Firebase chưa được cấu hình trên nền tảng hiện tại.');
    }
    try {
      // Trên Web, Firebase tự mở cửa sổ chọn tài khoản Google.
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        googleProvider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });

        return await _firebaseAuth.signInWithPopup(googleProvider);
      }

      // Trên Android, sử dụng plugin google_sign_in.
      await _initializeGoogleSignIn();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuthentication =
          googleUser.authentication;

      final OAuthCredential firebaseCredential = GoogleAuthProvider.credential(
        idToken: googleAuthentication.idToken,
      );

      return await _firebaseAuth.signInWithCredential(firebaseCredential);
    } on FirebaseAuthException {
      rethrow;
    } catch (error) {
      throw Exception('Không thể đăng nhập bằng Google: $error');

    }
  }

  Future<void> signOut() async {
    if (!isConfigured) {
      throw StateError('Firebase chưa được cấu hình trên nền tảng hiện tại.');
    }
    await _firebaseAuth.signOut();

    if (!kIsWeb) {

      await _googleSignIn.signOut();
    }
  }
}
