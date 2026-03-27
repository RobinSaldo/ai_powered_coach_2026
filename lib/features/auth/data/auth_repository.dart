import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/providers/firebase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  return AuthRepository(auth, firestore);
});

class AuthRepository {
  AuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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
            await _firestore
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .set({
                  'lastLoginAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }
          return credential;
        });
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth
        .createUserWithEmailAndPassword(email: email, password: password)
        .then((credential) async {
          final user = credential.user;
          if (user != null) {
            await _createUserProfile(user: user);
          }
          return credential;
        });
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> _createUserProfile({required User user}) {
    final now = FieldValue.serverTimestamp();
    final usernameSeed = user.email?.split('@').first ?? 'Student';

    return _firestore.collection(FirestoreCollections.users).doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': usernameSeed,
      'photoUrl': user.photoURL,
      'targetGoal': 'Improve speaking confidence',
      'skillLevel': 'Beginner',
      'currentStreak': 0,
      'totalSessions': 0,
      'avgScore': 0,
      'createdAt': now,
      'lastLoginAt': now,
    }, SetOptions(merge: true));
  }
}
