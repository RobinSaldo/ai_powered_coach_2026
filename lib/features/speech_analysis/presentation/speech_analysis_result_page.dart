import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SpeechAnalysisResultPage extends StatelessWidget {
  const SpeechAnalysisResultPage({required this.result, super.key});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final overallScore = (result['overallScore'] as num?)?.round() ?? 0;
    final deliveryScore = (result['deliveryScore'] as num?)?.round() ?? 0;
    final contentScore = (result['contentScore'] as num?)?.round() ?? 0;
    final confidence = (result['confidenceEstimate'] as num?)?.round() ?? 0;
    final words = (result['words'] as num?)?.toInt() ?? 0;
    final wpm = (result['wordsPerMinute'] as num?)?.toInt() ?? 0;
    final fillerWords = (result['fillerWords'] as num?)?.toInt() ?? 0;
    final coherenceScore = (result['coherenceScore'] as num?)?.toInt() ?? 0;
    final relevanceScore = (result['relevanceScore'] as num?)?.toInt() ?? 0;
    final grammarScore = (result['grammarScore'] as num?)?.toInt() ?? 0;
    final effectivenessScore =
        (result['effectivenessScore'] as num?)?.toInt() ?? 0;
    final topic = (result['topic'] as String?)?.trim() ?? '';
    final transcript = (result['transcript'] as String?) ?? '';
    final strengths = _toStringList(result['strengths']);
    final improvements = _toStringList(result['improvements']);

    return Scaffold(
      appBar: AppBar(title: const Text('Speech Analysis Result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScoreCard(
                overallScore: overallScore,
                deliveryScore: deliveryScore,
                contentScore: contentScore,
                confidence: confidence,
              ),
              if (topic.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Session Topic: $topic',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF35536D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Session Snapshot',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SnapshotCard(
                      label: 'Words',
                      value: '$words',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SnapshotCard(
                      label: 'Pace',
                      value: '$wpm WPM',
                      icon: Icons.speed_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SnapshotCard(
                      label: 'Filler',
                      value: '$fillerWords',
                      icon: Icons.hearing_disabled_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Content Assessment',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _AssessmentMetricCard(
                    label: 'Coherence',
                    score: coherenceScore,
                    icon: Icons.account_tree_outlined,
                  ),
                  _AssessmentMetricCard(
                    label: 'Relevance',
                    score: relevanceScore,
                    icon: Icons.gps_fixed_rounded,
                  ),
                  _AssessmentMetricCard(
                    label: 'Grammar',
                    score: grammarScore,
                    icon: Icons.spellcheck_rounded,
                  ),
                  _AssessmentMetricCard(
                    label: 'Effectiveness',
                    score: effectivenessScore,
                    icon: Icons.campaign_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Strengths',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _BulletList(items: strengths),
              const SizedBox(height: 16),
              Text(
                'Areas to Improve',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _BulletList(items: improvements),
              const SizedBox(height: 16),
              Text(
                'Transcript',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD2E6F9)),
                ),
                child: Text(
                  transcript.trim().isEmpty
                      ? 'No transcript captured.'
                      : transcript,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF35536D),
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/recommendations'),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('View Personalized Feedback'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/progress'),
                  icon: const Icon(Icons.timeline_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('View Progress Tracking'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.home_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Back to Dashboard'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.overallScore,
    required this.deliveryScore,
    required this.contentScore,
    required this.confidence,
  });

  final int overallScore;
  final int deliveryScore;
  final int contentScore;
  final int confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
            'Overall Score',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$overallScore / 100',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ScoreMetric(label: 'Delivery', value: '$deliveryScore'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreMetric(label: 'Content', value: '$contentScore'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ScoreMetric(label: 'Confidence', value: '$confidence%'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreMetric extends StatelessWidget {
  const _ScoreMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0E4F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1A6FAF)),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5A7792)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF133B5C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentMetricCard extends StatelessWidget {
  const _AssessmentMetricCard({
    required this.label,
    required this.score,
    required this.icon,
  });

  final String label;
  final int score;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0E4F8)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F3FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1A6FAF)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5A7792),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$score / 100',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF133B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No items yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF58758F)),
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
