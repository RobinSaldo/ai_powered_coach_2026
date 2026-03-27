import 'package:ai_powered_coach_2026/features/recommendations/domain/personalized_feedback_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PersonalizedFeedbackEngine', () {
    final engine = PersonalizedFeedbackEngine();

    test('returns starter plan when there are no sessions', () {
      final result = engine.build(sessions: const []);

      expect(result.avgOverall, 0);
      expect(result.avgDelivery, 0);
      expect(result.avgContent, 0);
      expect(result.recommendations, isNotEmpty);
      expect(result.recommendations.first.category, 'starting_plan');
    });

    test('returns focused recommendations for weak session trends', () {
      final sessions = [
        {
          'overallScore': 62,
          'deliveryScore': 60,
          'contentScore': 58,
          'wordsPerMinute': 82,
          'fillerWords': 7,
          'confidenceEstimate': 70,
          'coherenceScore': 60,
          'grammarScore': 66,
        },
        {
          'overallScore': 64,
          'deliveryScore': 63,
          'contentScore': 61,
          'wordsPerMinute': 90,
          'fillerWords': 6,
          'confidenceEstimate': 72,
          'coherenceScore': 62,
          'grammarScore': 68,
        },
      ];

      final result = engine.build(sessions: sessions);
      final categories = result.recommendations.map((r) => r.category).toSet();

      expect(
        result.focusAreas.any((f) => f.toLowerCase().contains('pace')),
        isTrue,
      );
      expect(categories.contains('pace'), isTrue);
      expect(categories.contains('filler_words'), isTrue);
      expect(categories.contains('content'), isTrue);
      expect(categories.contains('coherence'), isTrue);
      expect(categories.contains('grammar'), isTrue);
      expect(categories.contains('confidence'), isTrue);
    });

    test('returns maintenance recommendation when performance is strong', () {
      final sessions = [
        {
          'overallScore': 88,
          'deliveryScore': 86,
          'contentScore': 85,
          'wordsPerMinute': 128,
          'fillerWords': 1,
          'confidenceEstimate': 90,
          'coherenceScore': 84,
          'grammarScore': 87,
        },
        {
          'overallScore': 90,
          'deliveryScore': 89,
          'contentScore': 88,
          'wordsPerMinute': 132,
          'fillerWords': 1,
          'confidenceEstimate': 91,
          'coherenceScore': 86,
          'grammarScore': 89,
        },
      ];

      final result = engine.build(sessions: sessions);

      expect(result.avgOverall, closeTo(89.0, 0.01));
      expect(result.recommendations, isNotEmpty);
      expect(result.recommendations.first.category, 'consistency');
      expect(result.strengths, isNotEmpty);
    });
  });
}
