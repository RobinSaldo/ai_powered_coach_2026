class ContentAssessmentResult {
  const ContentAssessmentResult({
    required this.coherenceScore,
    required this.relevanceScore,
    required this.grammarScore,
    required this.effectivenessScore,
    required this.contentScore,
    required this.strengths,
    required this.improvements,
  });

  final int coherenceScore;
  final int relevanceScore;
  final int grammarScore;
  final int effectivenessScore;
  final int contentScore;
  final List<String> strengths;
  final List<String> improvements;
}

class ContentAssessmentService {
  ContentAssessmentResult assess({required String transcript, String? topic}) {
    final normalized = transcript.trim();
    final words = _splitWords(normalized);
    final sentences = _splitSentences(normalized);

    final coherenceScore = _coherenceScore(normalized, sentences);
    final relevanceScore = _relevanceScore(normalized, topic);
    final grammarScore = _grammarScore(normalized, words);
    final effectivenessScore = _effectivenessScore(
      words.length,
      sentences.length,
    );
    final contentScore =
        ((coherenceScore + relevanceScore + grammarScore + effectivenessScore) /
                4)
            .round()
            .clamp(0, 100)
            .toInt();

    final strengths = <String>[];
    final improvements = <String>[];

    if (coherenceScore >= 75) {
      strengths.add('Your ideas are arranged in a logical flow.');
    } else {
      improvements.add(
        'Use transitions like "first", "next", and "because" to improve flow.',
      );
    }

    if (relevanceScore >= 75) {
      strengths.add('Your response stays close to the topic.');
    } else {
      improvements.add(
        'Mention topic keywords more clearly to improve relevance.',
      );
    }

    if (grammarScore >= 75) {
      strengths.add('Sentence structure is generally clear.');
    } else {
      improvements.add(
        'Use complete sentences and avoid repeating the same phrase.',
      );
    }

    if (effectivenessScore >= 75) {
      strengths.add('Your message is sufficiently detailed.');
    } else {
      improvements.add(
        'Add examples or supporting points for stronger communication.',
      );
    }

    if (strengths.isEmpty) {
      strengths.add('You completed the speaking response successfully.');
    }
    if (improvements.isEmpty) {
      improvements.add(
        'Keep practicing to maintain your current content quality.',
      );
    }

    return ContentAssessmentResult(
      coherenceScore: coherenceScore,
      relevanceScore: relevanceScore,
      grammarScore: grammarScore,
      effectivenessScore: effectivenessScore,
      contentScore: contentScore,
      strengths: strengths,
      improvements: improvements,
    );
  }

  int _coherenceScore(String transcript, List<String> sentences) {
    if (transcript.isEmpty) return 0;

    const transitions = [
      'first',
      'second',
      'next',
      'then',
      'because',
      'therefore',
      'however',
      'finally',
      'for example',
      'in conclusion',
    ];

    var transitionCount = 0;
    final lower = transcript.toLowerCase();
    for (final transition in transitions) {
      transitionCount += RegExp(
        '\\b${RegExp.escape(transition)}\\b',
      ).allMatches(lower).length;
    }

    final sentenceFactor = (sentences.length * 10).clamp(10, 30);
    final transitionFactor = (transitionCount * 15).clamp(0, 35);
    final lengthFactor = transcript.length.clamp(0, 35);
    final score = sentenceFactor + transitionFactor + lengthFactor;
    return score.clamp(0, 100).toInt();
  }

  int _relevanceScore(String transcript, String? topic) {
    if (transcript.isEmpty) return 0;
    final cleanTopic = (topic ?? '').trim().toLowerCase();
    if (cleanTopic.isEmpty) {
      return 72;
    }

    final topicWords = cleanTopic
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length > 3)
        .toSet();
    if (topicWords.isEmpty) {
      return 70;
    }

    final transcriptWords = transcript
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .toSet();
    final matchCount = topicWords.where(transcriptWords.contains).length;
    final matchRatio = matchCount / topicWords.length;
    final score = (45 + (matchRatio * 55)).round();
    return score.clamp(0, 100).toInt();
  }

  int _grammarScore(String transcript, List<String> words) {
    if (transcript.isEmpty) return 0;

    var score = 82;
    if (!RegExp(r'[.!?]$').hasMatch(transcript.trim())) {
      score -= 8;
    }

    final repeatedWordsPenalty = _countImmediateWordRepetitions(words) * 4;
    score -= repeatedWordsPenalty.clamp(0, 24);

    final longStretchNoPunctuation = RegExp(
      r'[^.!?]{90,}',
    ).hasMatch(transcript);
    if (longStretchNoPunctuation) {
      score -= 10;
    }

    return score.clamp(0, 100).toInt();
  }

  int _effectivenessScore(int wordCount, int sentenceCount) {
    if (wordCount == 0) return 0;

    var score = 50;
    score += (wordCount * 1.2).round().clamp(0, 35);
    score += (sentenceCount * 5).clamp(0, 15).toInt();
    return score.clamp(0, 100).toInt();
  }

  List<String> _splitWords(String text) {
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
  }

  List<String> _splitSentences(String text) {
    if (text.isEmpty) return const [];
    return text
        .split(RegExp(r'[.!?]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  int _countImmediateWordRepetitions(List<String> words) {
    if (words.length < 2) return 0;

    var repetitions = 0;
    for (var i = 1; i < words.length; i++) {
      final previous = words[i - 1].toLowerCase();
      final current = words[i].toLowerCase();
      if (previous == current) {
        repetitions++;
      }
    }
    return repetitions;
  }
}
