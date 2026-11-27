import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Wraps Firebase Authentication for email/password and Google Sign-In.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Signs in with Google using popup flow on Web.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      return _auth.signInWithPopup(provider);
    }
    final provider = GoogleAuthProvider();
    return _auth.signInWithProvider(provider);
  }

  /// Signs in with an existing email and password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new account with email and password.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Extracts `oobCode` from a Firebase reset URL or returns the raw code.
  static String extractResetCode(String codeOrUrl) {
    final trimmed = codeOrUrl.trim();
    final uri = Uri.tryParse(trimmed);
    final oob = uri?.queryParameters['oobCode'];
    if (oob != null && oob.isNotEmpty) return oob;
    return trimmed;
  }

  /// Confirms a password reset inside the app using the email link or `oobCode`.
  Future<void> confirmPasswordReset({
    required String codeOrUrl,
    required String newPassword,
  }) {
    final code = extractResetCode(codeOrUrl);
    return _auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  /// Signs out the current user.
  Future<void> signOut() => _auth.signOut();
}

