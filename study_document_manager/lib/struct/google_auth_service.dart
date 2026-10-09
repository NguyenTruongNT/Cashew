import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';


class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();


  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  bool get isSignedIn => currentUser != null;

  Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized || kIsWeb) {
      return;
    }

    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trên Web, Firebase tự mở cửa sổ chọn tài khoản Google.
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();

        googleProvider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });

        return await _firebaseAuth.signInWithPopup(googleProvider);
      }

      // Trên Android/iOS, sử dụng plugin google_sign_in.
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

    await _firebaseAuth.signOut();

    if (!kIsWeb) {

      await _googleSignIn.signOut();
    }
  }
}
