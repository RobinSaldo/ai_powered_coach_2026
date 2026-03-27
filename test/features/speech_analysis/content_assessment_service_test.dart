import 'package:ai_powered_coach_2026/features/speech_analysis/domain/content_assessment_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentAssessmentService', () {
    final service = ContentAssessmentService();

    test('returns low scores for empty transcript', () {
      final result = service.assess(
        transcript: '',
        topic: 'job interview self introduction',
      );

      expect(result.contentScore, 0);
      expect(result.coherenceScore, 0);
      expect(result.relevanceScore, 0);
      expect(result.grammarScore, 0);
      expect(result.effectivenessScore, 0);
      expect(result.strengths, isNotEmpty);
      expect(result.improvements, isNotEmpty);
    });

    test('gives stronger scores for structured and relevant transcript', () {
      final result = service.assess(
        transcript:
            'First, I will introduce myself. Next, I will discuss my internship experience because it is relevant to this job interview. Finally, I will explain why my communication skills fit your team.',
        topic: 'job interview communication skills',
      );

      expect(result.coherenceScore, greaterThanOrEqualTo(75));
      expect(result.relevanceScore, greaterThanOrEqualTo(75));
      expect(result.grammarScore, greaterThanOrEqualTo(70));
      expect(result.effectivenessScore, greaterThanOrEqualTo(70));
      expect(result.contentScore, greaterThanOrEqualTo(70));
      expect(
        result.strengths.any((s) => s.toLowerCase().contains('topic')),
        isTrue,
      );
    });

    test('applies grammar penalty for repetition and missing punctuation', () {
      final result = service.assess(
        transcript:
            'hello hello hello hello this is my answer but i keep repeating repeating repeating',
        topic: 'self introduction',
      );

      expect(result.grammarScore, lessThan(75));
      expect(
        result.improvements.any((i) => i.toLowerCase().contains('sentence')),
        isTrue,
      );
    });
  });
}
