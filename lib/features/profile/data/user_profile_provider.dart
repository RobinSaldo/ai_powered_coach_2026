import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/providers/firebase_providers.dart';

final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  final user = auth.currentUser;

  if (user == null) {
    return Stream.value(null);
  }

  return firestore
      .collection(FirestoreCollections.users)
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        return doc.data();
      });
});
