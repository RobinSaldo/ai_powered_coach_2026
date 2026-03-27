import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_empty_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_error_view.dart';
import 'package:ai_powered_coach_2026/core/widgets/app_loading_view.dart';

class ProgressTrackingPage extends StatelessWidget {
  const ProgressTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: AppEmptyView(
          message: 'Please login to view your progress history.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }

    final query = FirebaseFirestore.instance
        .collection(FirestoreCollections.analysisResults)
        .where('userId', isEqualTo: user.uid)
        .limit(30);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress Tracking')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingView(
                message: 'Loading your progress report...',
              );
            }
            if (snapshot.hasError) {
              return const AppErrorView(
                message:
                    'Cannot load progress right now. Check Firestore rules/indexes.',
              );
            }

            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const AppEmptyView(
                message: 'No sessions yet. Complete a speaking session first.',
                icon: Icons.timeline_rounded,
              );
            }

            final entries = docs.map((doc) => doc.data()).toList();
            entries.sort((a, b) {
              final aTime = a['createdAt'] is Timestamp
                  ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
                  : 0;
              final bTime = b['createdAt'] is Timestamp
                  ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
                  : 0;
              return bTime.compareTo(aTime);
            });
            final summary = _buildSummary(entries);

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ProgressSummaryCard(summary: summary),
                const SizedBox(height: 14),
                _ScoreTrendCard(entries: entries),
                const SizedBox(height: 14),
                Text(
                  'Recent Sessions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionTile(entry: entry),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  _ProgressSummary _buildSummary(List<Map<String, dynamic>> entries) {
    final total = entries.length;
    final overallScores = entries
        .map((e) => (e['overallScore'] as num?)?.toDouble() ?? 0)
        .toList();
    final deliveryScores = entries
        .map((e) => (e['deliveryScore'] as num?)?.toDouble() ?? 0)
        .toList();
    final contentScores = entries
        .map((e) => (e['contentScore'] as num?)?.toDouble() ?? 0)
        .toList();

    final avgOverall = _average(overallScores);
    final avgDelivery = _average(deliveryScores);
    final avgContent = _average(contentScores);
    final bestOverall = overallScores.reduce((a, b) => a > b ? a : b);
    final latest = overallScores.isNotEmpty ? overallScores.first : 0.0;
    final trend = latest - avgOverall;

    return _ProgressSummary(
      totalSessions: total,
      avgOverall: avgOverall,
      avgDelivery: avgDelivery,
      avgContent: avgContent,
      bestOverall: bestOverall,
      trendFromAverage: trend,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    final sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }
}

class _ProgressSummaryCard extends StatelessWidget {
  const _ProgressSummaryCard({required this.summary});

  final _ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final trendLabel = summary.trendFromAverage >= 0
        ? '+${summary.trendFromAverage.toStringAsFixed(1)}'
        : summary.trendFromAverage.toStringAsFixed(1);

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
            'Progress Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sessions: ${summary.totalSessions}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Overall',
                  value: summary.avgOverall.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Delivery',
                  value: summary.avgDelivery.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: 'Avg Content',
                  value: summary.avgContent.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Best Score: ${summary.bestOverall.toStringAsFixed(1)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Trend: $trendLabel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
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

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final overall = (entry['overallScore'] as num?)?.toInt() ?? 0;
    final delivery = (entry['deliveryScore'] as num?)?.toInt() ?? 0;
    final content = (entry['contentScore'] as num?)?.toInt() ?? 0;
    final topic = (entry['topic'] as String?)?.trim();
    final createdAt = entry['createdAt'] is Timestamp
        ? (entry['createdAt'] as Timestamp).toDate()
        : null;
    final dateLabel = _formatDate(createdAt);

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
          Text(
            topic == null || topic.isEmpty ? 'Untitled Session' : topic,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF123B5C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5B7892)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SmallScore(label: 'Overall', value: '$overall'),
              const SizedBox(width: 8),
              _SmallScore(label: 'Delivery', value: '$delivery'),
              const SizedBox(width: 8),
              _SmallScore(label: 'Content', value: '$content'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'No date';
    }

    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }
}

class _ScoreTrendCard extends StatelessWidget {
  const _ScoreTrendCard({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final reversed = entries.reversed.toList();
    final points = <FlSpot>[];
    final labels = <String>[];

    for (var i = 0; i < reversed.length; i++) {
      final entry = reversed[i];
      final score = (entry['overallScore'] as num?)?.toDouble() ?? 0;
      points.add(FlSpot(i.toDouble(), score));
      labels.add('S${i + 1}');
    }
    final maxX = (points.length - 1).toDouble();
    final labelStep = labels.length > 8 ? (labels.length / 8).ceil() : 1;

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
          Text(
            'Overall Score Trend',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF123B5C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Shows your score progression per session.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5A7792)),
          ),
          const SizedBox(height: 12),
          if (points.length < 2)
            const AppEmptyView(
              message: 'Complete at least 2 sessions to view trend chart.',
              icon: Icons.show_chart_rounded,
            )
          else
            SizedBox(
              height: 210,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xFFE8F2FB),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xFFD0E4F8)),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5C7992),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final rounded = value.roundToDouble();
                          if ((value - rounded).abs() > 0.001) {
                            return const SizedBox.shrink();
                          }

                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }

                          final showLabel =
                              index == labels.length - 1 ||
                              index % labelStep == 0;
                          if (!showLabel) {
                            return const SizedBox.shrink();
                          }

                          return Text(
                            labels[index],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5C7992),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(10),
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          return LineTooltipItem(
                            'Score: ${spot.y.toStringAsFixed(0)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      color: const Color(0xFF2A8BDC),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(
                            radius: 3.2,
                            color: const Color(0xFF2A8BDC),
                            strokeWidth: 1.2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x3B2A8BDC), Color(0x062A8BDC)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallScore extends StatelessWidget {
  const _SmallScore({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4C6E8A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF134061),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSummary {
  const _ProgressSummary({
    required this.totalSessions,
    required this.avgOverall,
    required this.avgDelivery,
    required this.avgContent,
    required this.bestOverall,
    required this.trendFromAverage,
  });

  final int totalSessions;
  final double avgOverall;
  final double avgDelivery;
  final double avgContent;
  final double bestOverall;
  final double trendFromAverage;
}
