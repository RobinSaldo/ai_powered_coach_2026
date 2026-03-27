import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_empty_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';
import 'package:ai_powered_coach_2026/features/recommendations/domain/personalized_feedback_engine.dart';

class RecommendationsPage extends StatelessWidget {
  const RecommendationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: AppEmptyView(
          message: 'Please login to view personalized recommendations.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.analysisResults)
        .where('userId', isEqualTo: user.uid)
        .limit(50)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Personalized Feedback')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(
                message: 'Loading personalized feedback...',
              );
            }
            if (snapshot.hasError) {
              return const AppErrorView(
                message:
                    'Cannot load recommendations right now. Please check Firestore setup.',
              );
            }

            final docs = snapshot.data?.docs ?? const [];
            final sessions = docs.map((doc) => doc.data()).toList();
            sessions.sort((a, b) {
              final aTime = a['createdAt'] is Timestamp
                  ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
                  : 0;
              final bTime = b['createdAt'] is Timestamp
                  ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
                  : 0;
              return bTime.compareTo(aTime);
            });

            final engine = PersonalizedFeedbackEngine();
            final feedback = engine.build(sessions: sessions);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _FeedbackSummaryCard(feedback: feedback),
                const SizedBox(height: 14),
                Text(
                  'Your Strengths',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _ListSection(items: feedback.strengths),
                const SizedBox(height: 14),
                Text(
                  'Priority Focus Areas',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _ListSection(items: feedback.focusAreas),
                const SizedBox(height: 14),
                Text(
                  'Custom Recommendations (Cloud)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _CloudRecommendationsSection(
                  userId: user.uid,
                  fallback: feedback.recommendations,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackSummaryCard extends StatelessWidget {
  const _FeedbackSummaryCard({required this.feedback});

  final PersonalizedFeedbackResult feedback;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F86D8), Color(0xFF52ACEF)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized Snapshot',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Overall',
                  value: feedback.avgOverall.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Delivery',
                  value: feedback.avgDelivery.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Content',
                  value: feedback.avgContent.toStringAsFixed(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No items yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5A7690)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 7, color: Color(0xFF2A77B5)),
              ),
              Expanded(
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF35536D),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item});

  final PersonalizedRecommendation item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2E6F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PriorityBadge(priority: item.priority),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF3F5E79)),
          ),
          const SizedBox(height: 8),
          ...item.actionSteps.map((step) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF2378B6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4E6A83),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CloudRecommendationsSection extends StatelessWidget {
  const _CloudRecommendationsSection({
    required this.userId,
    required this.fallback,
  });

  final String userId;
  final List<PersonalizedRecommendation> fallback;

  @override
  Widget build(BuildContext context) {
    final cloudStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.recommendations)
        .where('userId', isEqualTo: userId)
        .limit(50)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: cloudStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFallbackList(
            context,
            fallback,
            'Cloud recommendations unavailable. Showing generated recommendations.',
          );
        }

        if (!snapshot.hasData) {
          return const AppLoadingView(
            message: 'Loading cloud recommendations...',
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final cloudItems = docs.map(_FirestoreRecommendation.fromDoc).toList();
        cloudItems.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
        final activeItems = cloudItems
            .where((item) => !item.isCompleted)
            .toList();

        if (activeItems.isEmpty) {
          return _buildFallbackList(
            context,
            fallback,
            'No active cloud recommendations yet. Showing generated recommendations.',
          );
        }

        return Column(
          children: activeItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FirestoreRecommendationCard(item: item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFallbackList(
    BuildContext context,
    List<PersonalizedRecommendation> items,
    String? message,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message != null) ...[
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5B7892)),
          ),
          const SizedBox(height: 8),
        ],
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RecommendationCard(item: item),
          );
        }),
      ],
    );
  }
}

class _FirestoreRecommendation {
  const _FirestoreRecommendation({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.actionSteps,
    required this.isCompleted,
    required this.createdAtMs,
    required this.category,
  });

  final String id;
  final String title;
  final String message;
  final String priority;
  final List<String> actionSteps;
  final bool isCompleted;
  final int createdAtMs;
  final String category;

  factory _FirestoreRecommendation.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).millisecondsSinceEpoch
        : 0;
    final rawSteps = (data['actionSteps'] as List?) ?? const [];
    final actionSteps = rawSteps.whereType<String>().toList();

    return _FirestoreRecommendation(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Recommendation',
      message: (data['message'] as String?) ?? 'No details available.',
      priority: (data['priority'] as String?) ?? 'low',
      actionSteps: actionSteps,
      isCompleted: (data['isCompleted'] as bool?) ?? false,
      createdAtMs: createdAt,
      category: (data['category'] as String?) ?? 'general',
    );
  }
}

class _FirestoreRecommendationCard extends StatelessWidget {
  const _FirestoreRecommendationCard({required this.item});

  final _FirestoreRecommendation item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD2E6F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _PriorityBadge(priority: item.priority),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Category: ${item.category}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF587690)),
          ),
          const SizedBox(height: 6),
          Text(
            item.message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF3F5E79)),
          ),
          const SizedBox(height: 8),
          ...item.actionSteps.map((step) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF2378B6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4E6A83),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection(FirestoreCollections.recommendations)
                    .doc(item.id)
                    .set({
                      'isCompleted': true,
                      'completedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Mark as Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final lower = priority.toLowerCase();
    final color = switch (lower) {
      'high' => const Color(0xFFB33131),
      'medium' => const Color(0xFF9A6700),
      _ => const Color(0xFF1A6FAF),
    };
    final background = switch (lower) {
      'high' => const Color(0xFFFFE8E8),
      'medium' => const Color(0xFFFFF4DE),
      _ => const Color(0xFFE9F5FF),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${priority.toUpperCase()} PRIORITY',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
