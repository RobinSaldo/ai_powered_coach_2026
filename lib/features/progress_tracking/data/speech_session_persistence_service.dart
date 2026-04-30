import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';

class SpeechSessionPersistenceService {
  SpeechSessionPersistenceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> saveSessionWithAnalysis({
    required String topic,
    required String transcript,
    required int durationSec,
    required Map<String, dynamic> analysis,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User must be logged in to save session.');
    }

    final userId = user.uid;
    final sessionRef = _firestore
        .collection(FirestoreCollections.speechSessions)
        .doc();
    final sessionId = sessionRef.id;
    final createdAt = FieldValue.serverTimestamp();

    final words = (analysis['words'] as num?)?.toInt() ?? 0;
    final wordsPerMinute = (analysis['wordsPerMinute'] as num?)?.toInt() ?? 0;
    final fillerWords = (analysis['fillerWords'] as num?)?.toInt() ?? 0;
    final confidenceEstimate =
        (analysis['confidenceEstimate'] as num?)?.toInt() ?? 0;
    final paceLabel = (analysis['paceLabel'] as String?) ?? '';

    await sessionRef.set({
      'sessionId': sessionId,
      'userId': userId,
      'topic': topic,
      'transcript': transcript,
      'durationSec': durationSec,
      'words': words,
      'wordsPerMinute': wordsPerMinute,
      'fillerWords': fillerWords,
      'confidenceEstimate': confidenceEstimate,
      'paceLabel': paceLabel,
      'createdAt': createdAt,
    });

    await _firestore
        .collection(FirestoreCollections.analysisResults)
        .doc(sessionId)
        .set({
          'analysisId': sessionId,
          'sessionId': sessionId,
          'userId': userId,
          'topic': topic,
          'transcript': transcript,
          'overallScore': analysis['overallScore'],
          'deliveryScore': analysis['deliveryScore'],
          'contentScore': analysis['contentScore'],
          'coherenceScore': analysis['coherenceScore'],
          'relevanceScore': analysis['relevanceScore'],
          'grammarScore': analysis['grammarScore'],
          'effectivenessScore': analysis['effectivenessScore'],
          'confidenceEstimate': confidenceEstimate,
          'words': words,
          'wordsPerMinute': wordsPerMinute,
          'fillerWords': fillerWords,
          'detectedFillers': analysis['detectedFillers'] ?? const [],
          'strengths': analysis['strengths'] ?? const [],
          'improvements': analysis['improvements'] ?? const [],
          'createdAt': createdAt,
        });

    await _saveRecommendations(
      userId: userId,
      sessionId: sessionId,
      topic: topic,
      analysis: analysis,
    );

    final score = (analysis['overallScore'] as num?)?.toDouble() ?? 0;
    await _updateUserStats(userId: userId, latestScore: score);
    return sessionId;
  }

  Future<void> _saveRecommendations({
    required String userId,
    required String sessionId,
    required String topic,
    required Map<String, dynamic> analysis,
  }) async {
    final entries = _buildRecommendationEntries(
      topic: topic,
      analysis: analysis,
    );

    final batch = _firestore.batch();
    for (final entry in entries) {
      final docRef = _firestore
          .collection(FirestoreCollections.recommendations)
          .doc();
      batch.set(docRef, {
        'recommendationId': docRef.id,
        'userId': userId,
        'sourceSessionId': sessionId,
        'category': entry['category'],
        'priority': entry['priority'],
        'title': entry['title'],
        'message': entry['message'],
        'actionSteps': entry['actionSteps'],
        'isCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 21)),
        ),
      });
    }
    await batch.commit();
  }

  List<Map<String, dynamic>> _buildRecommendationEntries({
    required String topic,
    required Map<String, dynamic> analysis,
  }) {
    final wordsPerMinute = (analysis['wordsPerMinute'] as num?)?.toInt() ?? 0;
    final fillerWords = (analysis['fillerWords'] as num?)?.toInt() ?? 0;
    final coherence = (analysis['coherenceScore'] as num?)?.toInt() ?? 0;
    final grammar = (analysis['grammarScore'] as num?)?.toInt() ?? 0;
    final contentScore = (analysis['contentScore'] as num?)?.toInt() ?? 0;
    final confidence = (analysis['confidenceEstimate'] as num?)?.toInt() ?? 0;

    final items = <Map<String, dynamic>>[];

    if (wordsPerMinute < 110) {
      items.add({
        'category': 'pace',
        'priority': 'high',
        'title': 'Increase Speaking Pace',
        'message': 'Your pace is below target. Aim for 110-140 WPM.',
        'actionSteps': const [
          'Practice one-minute responses with timer.',
          'Avoid long pauses between sentences.',
          'Re-record until pace enters target range.',
        ],
      });
    } else if (wordsPerMinute > 160) {
      items.add({
        'category': 'pace',
        'priority': 'medium',
        'title': 'Control Fast Delivery',
        'message': 'Your pace is fast. Slow down for clearer communication.',
        'actionSteps': const [
          'Pause after important points.',
          'Use shorter sentence groups.',
          'Target 120-150 WPM for clarity.',
        ],
      });
    }

    if (fillerWords > 2) {
      items.add({
        'category': 'filler_words',
        'priority': 'high',
        'title': 'Reduce Filler Words',
        'message': 'Frequent fillers reduce confidence impact.',
        'actionSteps': const [
          'Replace filler words with silent pauses.',
          'Mark filler words from transcript review.',
          'Practice key answers twice before recording.',
        ],
      });
    }

    if (coherence < 75) {
      items.add({
        'category': 'coherence',
        'priority': 'medium',
        'title': 'Improve Idea Flow',
        'message': 'Use transition cues for better coherence.',
        'actionSteps': const [
          'Use "first", "next", and "therefore".',
          'Follow opening-body-closing structure.',
          'Link each point to your main topic.',
        ],
      });
    }

    if (grammar < 75) {
      items.add({
        'category': 'grammar',
        'priority': 'medium',
        'title': 'Grammar Clarity Practice',
        'message': 'Improve sentence form and reduce repetition.',
        'actionSteps': const [
          'Speak in complete sentence chunks.',
          'Avoid repeating one word multiple times.',
          'Rewrite weak lines from transcript.',
        ],
      });
    }

    if (contentScore < 75) {
      items.add({
        'category': 'content',
        'priority': 'high',
        'title': 'Strengthen Content Quality',
        'message': 'Add support details and examples to your responses.',
        'actionSteps': const [
          'Use 3 key points per response.',
          'Add at least one example per key point.',
          'End with one clear takeaway sentence.',
        ],
      });
    }

    if (confidence < 80) {
      items.add({
        'category': 'confidence',
        'priority': 'medium',
        'title': 'Confidence Boost Drill',
        'message': 'Build confidence with controlled starts and breathing.',
        'actionSteps': const [
          'Take one deep breath before speaking.',
          'Start with a strong opening sentence.',
          'Practice in front of mirror for 2 minutes.',
        ],
      });
    }

    if (items.isEmpty) {
      items.add({
        'category': 'consistency',
        'priority': 'low',
        'title': 'Keep Your Momentum',
        'message': 'You are doing great. Maintain regular practice sessions.',
        'actionSteps': [
          'Complete at least 3 sessions this week.',
          'Try a harder topic: ${topic.isEmpty ? "public speaking" : topic}.',
          'Track your average score trend weekly.',
        ],
      });
    }

    return items;
  }

  Future<void> _updateUserStats({
    required String userId,
    required double latestScore,
  }) async {
    final userRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data() ?? <String, dynamic>{};
      final totalSessions = (data['totalSessions'] as num?)?.toInt() ?? 0;
      final currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
      final bestStreak = (data['bestStreak'] as num?)?.toInt() ?? 0;
      final currentAverage = (data['avgScore'] as num?)?.toDouble() ?? 0;
      final lastPracticeDate = _asDateTime(data['lastPracticeDate']);

      final today = _dayOnly(DateTime.now());
      final normalizedLastPractice = lastPracticeDate == null
          ? null
          : _dayOnly(lastPracticeDate);

      int nextCurrentStreak;
      if (normalizedLastPractice == null) {
        nextCurrentStreak = 1;
      } else {
        final dayGap = today.difference(normalizedLastPractice).inDays;
        if (dayGap <= 0) {
          nextCurrentStreak = currentStreak == 0 ? 1 : currentStreak;
        } else if (dayGap == 1) {
          nextCurrentStreak = currentStreak <= 0 ? 1 : currentStreak + 1;
        } else {
          nextCurrentStreak = 1;
        }
      }

      final nextBestStreak = math.max(bestStreak, nextCurrentStreak);
      final newTotal = totalSessions + 1;
      final newAverage =
          ((currentAverage * totalSessions) + latestScore) / newTotal;
      final inferredSkillLevel = _inferSkillLevel(
        avgScore: newAverage,
        totalSessions: newTotal,
        bestStreak: nextBestStreak,
      );

      transaction.set(userRef, {
        'totalSessions': newTotal,
        'currentStreak': nextCurrentStreak,
        'bestStreak': nextBestStreak,
        'lastPracticeDate': Timestamp.fromDate(today),
        'lastSessionAt': FieldValue.serverTimestamp(),
        'avgScore': double.parse(newAverage.toStringAsFixed(1)),
        'skillLevel': inferredSkillLevel,
        'skillLevelUpdatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  String _inferSkillLevel({
    required double avgScore,
    required int totalSessions,
    required int bestStreak,
  }) {
    if (totalSessions >= 12 && avgScore >= 82 && bestStreak >= 5) {
      return 'Advanced';
    }

    if (totalSessions >= 4 && avgScore >= 68) {
      return 'Intermediate';
    }

    return 'Beginner';
  }

  DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime _dayOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
