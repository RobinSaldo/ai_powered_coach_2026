class PersonalizedRecommendation {
  const PersonalizedRecommendation({
    required this.category,
    required this.priority,
    required this.title,
    required this.message,
    required this.actionSteps,
  });

  final String category;
  final String priority;
  final String title;
  final String message;
  final List<String> actionSteps;
}

class PersonalizedFeedbackResult {
  const PersonalizedFeedbackResult({
    required this.strengths,
    required this.focusAreas,
    required this.recommendations,
    required this.avgOverall,
    required this.avgDelivery,
    required this.avgContent,
  });

  final List<String> strengths;
  final List<String> focusAreas;
  final List<PersonalizedRecommendation> recommendations;
  final double avgOverall;
  final double avgDelivery;
  final double avgContent;
}

class PersonalizedFeedbackEngine {
  PersonalizedFeedbackResult build({
    required List<Map<String, dynamic>> sessions,
  }) {
    if (sessions.isEmpty) {
      return const PersonalizedFeedbackResult(
        strengths: ['You already completed your first setup.'],
        focusAreas: [
          'Complete 2-3 speaking sessions to unlock personalized insights.',
        ],
        recommendations: [
          PersonalizedRecommendation(
            category: 'starting_plan',
            priority: 'high',
            title: 'Start With Daily 3-Minute Practice',
            message:
                'Short daily sessions build momentum and improve confidence fast.',
            actionSteps: [
              'Do one 3-minute recording each day.',
              'Use a simple topic like self-introduction.',
              'Review your analysis after every session.',
            ],
          ),
        ],
        avgOverall: 0,
        avgDelivery: 0,
        avgContent: 0,
      );
    }

    final avgOverall = _average(
      sessions
          .map((e) => (e['overallScore'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
    final avgDelivery = _average(
      sessions
          .map((e) => (e['deliveryScore'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
    final avgContent = _average(
      sessions
          .map((e) => (e['contentScore'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
    final avgWpm = _average(
      sessions
          .map((e) => (e['wordsPerMinute'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
    final avgFiller = _average(
      sessions.map((e) => (e['fillerWords'] as num?)?.toDouble() ?? 0).toList(),
    );
    final avgConfidence = _average(
      sessions
          .map((e) => (e['confidenceEstimate'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
    final avgCoherence = _average(
      sessions
          .map((e) => (e['coherenceScore'] as num?)?.toDouble() ?? 0)
          .toList(),
    );
    final avgGrammar = _average(
      sessions
          .map((e) => (e['grammarScore'] as num?)?.toDouble() ?? 0)
          .toList(),
    );

    final strengths = <String>[];
    final focusAreas = <String>[];
    final recommendations = <PersonalizedRecommendation>[];

    if (avgWpm >= 110 && avgWpm <= 160) {
      strengths.add('Your speaking pace is in a strong range.');
    } else if (avgWpm < 110) {
      focusAreas.add('Increase speaking pace slightly for better engagement.');
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'pace',
          priority: 'high',
          title: 'Pace Training Drill',
          message: 'Your average pace is slow. Aim for 110-140 WPM.',
          actionSteps: [
            'Practice with a 60-second timer.',
            'Say complete thoughts without long pauses.',
            'Re-record until pace reaches at least 110 WPM.',
          ],
        ),
      );
    } else {
      focusAreas.add('Reduce pace slightly to improve clarity.');
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'pace',
          priority: 'medium',
          title: 'Clarity Pace Control',
          message: 'Your pace is fast. Slow down on key sentences.',
          actionSteps: [
            'Pause 1 second after each key point.',
            'Use shorter sentences while practicing.',
            'Target 120-150 WPM.',
          ],
        ),
      );
    }

    if (avgFiller <= 2) {
      strengths.add('You control filler words well.');
    } else {
      focusAreas.add('Reduce filler words for stronger confidence.');
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'filler_words',
          priority: 'high',
          title: 'Filler Word Reduction Plan',
          message:
              'You use filler words frequently. Replace them with silent pauses.',
          actionSteps: [
            'Speak 2-minute responses and count fillers.',
            'Pause instead of saying "um" or "uh".',
            'Repeat until filler count drops below 3.',
          ],
        ),
      );
    }

    if (avgContent >= 75) {
      strengths.add('Your content quality is improving.');
    } else {
      focusAreas.add('Improve content structure and supporting details.');
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'content',
          priority: 'high',
          title: 'Content Structure Routine',
          message: 'Your content score is low. Use clear structure every time.',
          actionSteps: [
            'Use 3-part flow: opening, body, closing.',
            'Add at least one example for each major point.',
            'End with one clear takeaway sentence.',
          ],
        ),
      );
    }

    if (avgCoherence >= 75) {
      strengths.add('Your ideas generally flow in logical order.');
    } else {
      focusAreas.add('Use transitions to connect ideas better.');
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'coherence',
          priority: 'medium',
          title: 'Transition Word Practice',
          message: 'Better transitions will improve your coherence quickly.',
          actionSteps: [
            'Use "first, next, because, therefore" in each session.',
            'Review transcript and mark transition words.',
            'Re-record if your response feels disconnected.',
          ],
        ),
      );
    }

    if (avgGrammar >= 75) {
      strengths.add('Grammar and sentence form are mostly clear.');
    } else {
      focusAreas.add('Practice complete sentences to improve grammar clarity.');
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'grammar',
          priority: 'medium',
          title: 'Grammar Clarity Drill',
          message: 'Your transcript shows incomplete or repetitive phrasing.',
          actionSteps: [
            'Speak in full sentence chunks.',
            'Avoid repeating the same word many times.',
            'Check transcript and rewrite weak lines.',
          ],
        ),
      );
    }

    if (avgConfidence >= 82) {
      strengths.add('Your confidence signals are strong.');
    } else {
      focusAreas.add(
        'Build confidence through breathing and deliberate starts.',
      );
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'confidence',
          priority: 'medium',
          title: 'Confidence Booster Routine',
          message: 'Your confidence can improve with controlled delivery.',
          actionSteps: [
            'Take one deep breath before speaking.',
            'Start with a strong first sentence.',
            'Keep eye line steady when practicing on camera.',
          ],
        ),
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        const PersonalizedRecommendation(
          category: 'consistency',
          priority: 'low',
          title: 'Maintain Momentum',
          message:
              'You are doing well. Keep consistency for continuous growth.',
          actionSteps: [
            'Complete at least 3 sessions per week.',
            'Increase topic difficulty gradually.',
            'Track weekly score trend and set a new target.',
          ],
        ),
      );
    }

    return PersonalizedFeedbackResult(
      strengths: strengths,
      focusAreas: focusAreas,
      recommendations: recommendations,
      avgOverall: avgOverall,
      avgDelivery: avgDelivery,
      avgContent: avgContent,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    final total = values.reduce((a, b) => a + b);
    return total / values.length;
  }
}
