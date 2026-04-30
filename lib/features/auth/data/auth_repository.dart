import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/providers/firebase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return AuthRepository(auth, firestore);
});

class AuthRepository {
  AuthRepository(this._auth, this._firestore) : _googleSignIn = GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .then((credential) async {
          final user = credential.user;
          if (user != null) {
            await _ensureUserProfile(user: user);
          }
          return credential;
        });
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) {
    return _auth
        .createUserWithEmailAndPassword(email: email, password: password)
        .then((credential) async {
          final user = credential.user;
          if (user != null) {
            final fullName = _buildDisplayName(
              firstName: firstName,
              lastName: lastName,
            );
            if (fullName.isNotEmpty) {
              await user.updateDisplayName(fullName);
            }
            await _createUserProfile(
              user: user,
              firstName: firstName,
              lastName: lastName,
            );
          }
          return credential;
        });
  }

  Future<UserCredential?> signInWithGoogle() async {
    UserCredential credential;
    if (kIsWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final authCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(authCredential);
    }

    final user = credential.user;
    if (user != null) {
      await _ensureUserProfile(user: user);
    }
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore Google sign-out issues so account logout still succeeds.
      }
    }
  }

  Future<void> _createUserProfile({
    required User user,
    required String firstName,
    required String lastName,
  }) {
    final sanitizedFirstName = _sanitizeName(firstName);
    final sanitizedLastName = _sanitizeName(lastName);
    final now = FieldValue.serverTimestamp();
    final displayName = _buildDisplayName(
      firstName: sanitizedFirstName,
      lastName: sanitizedLastName,
    );
    final usernameSeed = user.email?.split('@').first ?? 'Student';

    return _firestore.collection(FirestoreCollections.users).doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'firstName': sanitizedFirstName.isEmpty
          ? usernameSeed
          : sanitizedFirstName,
      'lastName': sanitizedLastName,
      'displayName': displayName.isEmpty ? usernameSeed : displayName,
      'photoUrl': user.photoURL,
      'role': 'user',
      'targetGoal': 'Improve speaking confidence',
      'skillLevel': 'Beginner',
      'currentStreak': 0,
      'bestStreak': 0,
      'totalSessions': 0,
      'avgScore': 0,
      'createdAt': now,
      'lastLoginAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> _ensureUserProfile({required User user}) async {
    final docRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid);
    final snapshot = await docRef.get();
    final currentData = snapshot.data() ?? <String, dynamic>{};
    final now = FieldValue.serverTimestamp();

    final emailSeed = user.email?.split('@').first ?? 'Student';
    final currentFirstName = _sanitizeName(currentData['firstName'] as String?);
    final currentLastName = _sanitizeName(currentData['lastName'] as String?);
    final currentDisplayName = _sanitizeName(
      currentData['displayName'] as String?,
    );
    final userDisplayName = _sanitizeName(user.displayName);

    final firstName = currentFirstName.isNotEmpty
        ? currentFirstName
        : (userDisplayName.isNotEmpty
              ? userDisplayName.split(' ').first
              : emailSeed);
    final lastName = currentLastName;
    final displayName = currentDisplayName.isNotEmpty
        ? currentDisplayName
        : (userDisplayName.isNotEmpty
              ? userDisplayName
              : _buildDisplayName(firstName: firstName, lastName: lastName));
    final existingPhotoUrl = _sanitizeName(currentData['photoUrl'] as String?);
    final resolvedPhotoUrl = _sanitizeName(user.photoURL).isNotEmpty
        ? _sanitizeName(user.photoURL)
        : existingPhotoUrl;

    final existingRole = _sanitizeRole(currentData['role'] as String?);

    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'firstName': firstName,
      'lastName': lastName,
      'displayName': displayName.isEmpty ? firstName : displayName,
      if (resolvedPhotoUrl.isNotEmpty) 'photoUrl': resolvedPhotoUrl,
      'role': existingRole,
      'lastLoginAt': now,
      if (!snapshot.exists) 'createdAt': now,
      if (!snapshot.exists) 'targetGoal': 'Improve speaking confidence',
      if (!snapshot.exists) 'skillLevel': 'Beginner',
      if (!snapshot.exists) 'currentStreak': 0,
      if (!snapshot.exists) 'bestStreak': 0,
      if (!snapshot.exists) 'totalSessions': 0,
      if (!snapshot.exists) 'avgScore': 0,
    }, SetOptions(merge: true));
  }

  String _sanitizeName(String? value) {
    return (value ?? '').trim();
  }

  String _buildDisplayName({
    required String firstName,
    required String lastName,
  }) {
    final merged = '$firstName $lastName'.trim();
    return merged.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _sanitizeRole(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'developer':
        return 'developer';
      default:
        return 'user';
    }
  }
}
