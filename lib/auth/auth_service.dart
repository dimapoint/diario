import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

@immutable
class AppUser {
  const AppUser({required this.uid, this.name, this.email, this.photoUrl});

  final String uid;
  final String? name;
  final String? email;
  final String? photoUrl;

  String get initial {
    final source = (name?.trim().isNotEmpty ?? false) ? name! : (email ?? '?');
    return source.isEmpty ? '?' : String.fromCharCode(source.runes.first).toUpperCase();
  }
}

abstract interface class AuthService {
  Stream<AppUser?> userChanges();
  Future<void> signIn();
  Future<void> signOut();
}

class SignInCancelled implements Exception {
  const SignInCancelled();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;
  Future<void>? _googleInit;

  static AppUser? _toAppUser(User? u) => u == null
      ? null
      : AppUser(uid: u.uid, name: u.displayName, email: u.email, photoUrl: u.photoURL);

  @override
  Stream<AppUser?> userChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  Future<void> signIn() async {
    if (kIsWeb) {
      try {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          throw const SignInCancelled();
        }
        rethrow;
      }
      return;
    }
    // Android: Credential Manager mediante google_sign_in. El client id
    // sale del google-services.json que genera `flutterfire configure`.
    final google = GoogleSignIn.instance;
    await (_googleInit ??= google.initialize());
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const SignInCancelled();
      rethrow;
    }
    final idToken = account.authentication.idToken;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb && _googleInit != null) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}

/// Usuario fijo para el modo demo y los tests.
class DemoAuthService implements AuthService {
  DemoAuthService({AppUser? user})
      : _user = user ?? const AppUser(uid: 'demo', name: 'Demo', email: 'demo@diario.app');

  final AppUser _user;

  @override
  Stream<AppUser?> userChanges() => Stream.value(_user);

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}
}
