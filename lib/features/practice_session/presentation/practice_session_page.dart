import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:ai_powered_coach_2026/services/speech/speech_to_text_service.dart';

class PracticeSessionPage extends StatefulWidget {
  const PracticeSessionPage({super.key});

  @override
  State<PracticeSessionPage> createState() => _PracticeSessionPageState();
}

class _PracticeSessionPageState extends State<PracticeSessionPage> {
  final _speechService = SpeechToTextService();

  _PracticeScript _selectedScript = _practiceScripts.first;
  List<_ScriptWord> _scriptWords = _buildScriptWords(
    _scriptTextForTarget(_practiceScripts.first),
  );
  bool _isSessionActive = false;
  bool _isBusy = false;
  bool _isRestarting = false;
  int _currentWordIndex = 0;
  String _statusText = 'Select a session and tap Start Practice.';
  String _recognizedPreview = '';
  String? _activeLocaleId;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _resumeListeningTimer;
  Timer? _listeningWatchdogTimer;
  _SessionSummary? _lastCompletedSummary;
  final Set<int> _skippedWordIndexes = <int>{};
  DateTime? _lastSkipCommandAt;

  static const _speechStartTimeout = Duration(seconds: 8);
  static const _speechInitTimeout = Duration(seconds: 6);
  static const _speechLocaleResolveTimeout = Duration(seconds: 3);
  static const _pauseTolerance = Duration(seconds: 20);
  static const _watchdogInterval = Duration(seconds: 2);
  static const int _matchScanWindow = 36;

  static const List<_PracticeScript> _practiceScripts = [
    _PracticeScript(
      id: 'job_intro',
      title: 'Job Interview Introduction',
      targetWords: 100,
      text:
          'Good day. My name is Alex Rivera, and I am applying for an entry-level software developer role. I recently finished my degree in information technology, where I built projects in Flutter and Firebase. During my internship, I collaborated with a small team to improve app performance, fix bugs, and deliver updates on time. I enjoy solving problems, learning quickly, and communicating clearly with teammates. If given the opportunity, I will contribute with discipline, consistency, and a strong willingness to grow with your company.',
    ),
    _PracticeScript(
      id: 'self_intro',
      title: 'Self Introduction',
      targetWords: 100,
      text:
          'Hello everyone. I am a student who is passionate about communication and technology. I am currently improving my public speaking skills by practicing every day with structured feedback. My strengths are dedication, adaptability, and teamwork. I value clear messages and respectful conversations because they help people understand each other better. In school projects, I usually help with planning, documentation, and app testing. My goal is to become more confident when presenting ideas and to speak with better pacing, clarity, and organization.',
    ),
    _PracticeScript(
      id: 'class_report',
      title: 'Class Reporting Summary',
      targetWords: 100,
      text:
          'Today, I will summarize the topic about effective communication. Effective communication happens when a message is delivered clearly, understood correctly, and responded to appropriately. It includes verbal skills, nonverbal cues, listening ability, and content structure. A good speaker should organize ideas into opening, body, and conclusion. The opening sets context, the body explains key points with examples, and the conclusion gives a clear takeaway. To improve communication, we must practice active listening, avoid unnecessary fillers, and adjust pace based on the audience.',
    ),
    _PracticeScript(
      id: 'debate',
      title: 'Debate Practice',
      targetWords: 100,
      text:
          'I strongly support the idea that students should learn practical communication skills before graduation. Academic knowledge is important, but communication determines how well ideas are shared in real situations. When students can explain clearly, ask good questions, and listen actively, they perform better in teamwork and leadership tasks. Employers also look for candidates who can present solutions with confidence. Therefore, schools should include regular speaking activities, feedback sessions, and role-based practice. This approach prepares students not only for exams but also for interviews, workplaces, and community engagement.',
    ),
    _PracticeScript(
      id: 'impromptu',
      title: 'Impromptu Speech',
      targetWords: 100,
      text:
          'If I could improve one daily habit, I would choose consistent practice. Small, repeated effort creates big progress over time. For speaking skills, ten focused minutes each day can improve pronunciation, pacing, and confidence. I would begin by selecting one topic, recording a short response, and reviewing weak points. Then I would repeat the session with clearer structure and fewer fillers. This routine is simple, realistic, and measurable. In the long term, consistency builds confidence because every practice session becomes proof of improvement.',
    ),
  ];

  static const String _fallbackPracticePadding =
      'I keep speaking with clear pacing, complete sentences, and confident delivery while I organize ideas and maintain strong audience focus.';

  static String _scriptTextForTarget(_PracticeScript script) {
    return _fitScriptToTargetWords(
      baseText: script.text,
      targetWords: script.targetWords,
    );
  }

  static String _fitScriptToTargetWords({
    required String baseText,
    required int targetWords,
  }) {
    if (targetWords <= 0) {
      return '';
    }

    final selectedTokens = <String>[];
    for (final token in baseText.split(RegExp(r'\s+'))) {
      if (_normalizeWord(token).isEmpty) {
        continue;
      }
      selectedTokens.add(token);
      if (selectedTokens.length >= targetWords) {
        return selectedTokens.join(' ');
      }
    }

    final paddingTokens = _fallbackPracticePadding
        .split(RegExp(r'\s+'))
        .where((token) => _normalizeWord(token).isNotEmpty)
        .toList(growable: false);

    if (paddingTokens.isEmpty) {
      return selectedTokens.join(' ');
    }

    var cursor = 0;
    while (selectedTokens.length < targetWords) {
      selectedTokens.add(paddingTokens[cursor % paddingTokens.length]);
      cursor++;
    }

    return selectedTokens.join(' ');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resumeListeningTimer?.cancel();
    _listeningWatchdogTimer?.cancel();
    unawaited(_speechService.cancelListening());
    super.dispose();
  }

  Future<void> _startPractice() async {
    if (_isBusy || _isSessionActive) {
      return;
    }

    setState(() {
      _isBusy = true;
      _currentWordIndex = 0;
      _recognizedPreview = '';
      _statusText = 'Preparing microphone...';
      _elapsed = Duration.zero;
      _lastCompletedSummary = null;
      _skippedWordIndexes.clear();
      _lastSkipCommandAt = null;
    });

    try {
      final micPermissionGranted = await _ensureMicrophonePermission();
      if (!micPermissionGranted) {
        _showSnack('Microphone permission is required.');
        setState(() {
          _statusText = 'Microphone permission required.';
        });
        return;
      }

      final available = await _speechService
          .initialize(
            onStatus: _handleSpeechStatus,
            onError: (error) {
              if (!mounted) {
                return;
              }
              setState(() {
                _statusText = 'Speech error: ${error.errorMsg}';
              });
            },
          )
          .timeout(_speechInitTimeout, onTimeout: () => false);

      if (!available) {
        _showSnack('Speech recognition is not available.');
        setState(() {
          _statusText = 'Speech recognition unavailable.';
        });
        return;
      }

      final locale = await _resolveSpeechLocale();
      _activeLocaleId = locale;

      final started = await _speechService
          .startListening(
            onResult: _onSpeechResult,
            listenFor: const Duration(minutes: 8),
            pauseFor: _pauseTolerance,
            localeId: locale,
          )
          .timeout(_speechStartTimeout, onTimeout: () => false);

      if (!started) {
        throw StateError('Speech recognition did not start.');
      }

      _startTimer();
      _startListeningWatchdog();
      setState(() {
        _isSessionActive = true;
        _statusText =
            'Listening... read the highlighted word in sequence to progress.';
      });
    } catch (error, stackTrace) {
      debugPrint('Start practice failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showSnack(
        kIsWeb
            ? 'Failed to start. Allow mic in browser permissions then retry.'
            : 'Failed to start practice session. Try again.',
      );
      if (mounted) {
        setState(() {
          _statusText = 'Could not start practice.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _stopPractice({bool completed = false}) async {
    if (_isBusy || !_isSessionActive) {
      return;
    }

    setState(() {
      _isBusy = true;
      _statusText = completed
          ? 'Practice complete. Great work.'
          : 'Stopping practice...';
    });

    try {
      await _speechService.stopListening();
    } catch (_) {
      _showSnack('Failed to stop listening. Try again.');
    } finally {
      _stopTimer();
      _resumeListeningTimer?.cancel();
      _resumeListeningTimer = null;
      _listeningWatchdogTimer?.cancel();
      _listeningWatchdogTimer = null;
      _isRestarting = false;
      if (mounted) {
        setState(() {
          _isSessionActive = false;
          _isBusy = false;
          if (!completed) {
            _statusText = 'Practice stopped. You can continue anytime.';
          }
        });
      }
    }
  }

  void _resetPractice() {
    if (_isSessionActive || _isBusy) {
      return;
    }

    setState(() {
      _currentWordIndex = 0;
      _recognizedPreview = '';
      _elapsed = Duration.zero;
      _statusText = 'Select a session and tap Start Practice.';
      _lastCompletedSummary = null;
      _skippedWordIndexes.clear();
      _lastSkipCommandAt = null;
    });
  }

  void _selectScript(_PracticeScript script) {
    if (_isSessionActive || _isBusy) {
      _showSnack('Stop the current practice session before switching topic.');
      return;
    }

    setState(() {
      _selectedScript = script;
      _scriptWords = _buildScriptWords(_scriptTextForTarget(script));
      _currentWordIndex = 0;
      _recognizedPreview = '';
      _elapsed = Duration.zero;
      _statusText = 'Script loaded. Tap Start Practice when ready.';
      _lastCompletedSummary = null;
      _skippedWordIndexes.clear();
      _lastSkipCommandAt = null;
    });
  }

  Future<bool> _ensureMicrophonePermission() async {
    if (kIsWeb) {
      return true;
    }
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String?> _resolveSpeechLocale() async {
    try {
      return await _speechService
          .resolveBestLocale(
            preferredLocaleIds: const ['en_PH', 'fil_PH', 'en_US'],
          )
          .timeout(_speechLocaleResolveTimeout, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_isSessionActive) {
      return;
    }

    final recognized = result.recognizedWords.trim();
    if (recognized.isEmpty) {
      return;
    }

    if (_isSkipCommand(recognized)) {
      _handleSkipWordCommand(recognized);
      return;
    }

    final normalized = _normalizedTokens(recognized);
    if (normalized.isEmpty) {
      return;
    }

    final nextIndex = _calculateNextWordIndex(
      heardTokens: normalized,
      startIndex: _currentWordIndex,
    );

    if (!mounted) {
      return;
    }

    if (nextIndex == _currentWordIndex) {
      if (_recognizedPreview == recognized) {
        return;
      }
      setState(() {
        _recognizedPreview = recognized;
        _statusText = 'Listening... keep reading the highlighted word.';
      });
      return;
    }

    final isCompleted = nextIndex >= _scriptWords.length;
    setState(() {
      _currentWordIndex = nextIndex;
      _recognizedPreview = recognized;
      _statusText = isCompleted
          ? 'All words matched. Finishing session...'
          : 'Good. Keep reading the next highlighted word.';
      if (isCompleted) {
        _lastCompletedSummary = _buildSessionSummary(
          completedWords: nextIndex,
          skippedWordIndexes: _skippedWordIndexes,
        );
      }
    });

    if (isCompleted) {
      final summary = _lastCompletedSummary;
      final hardSummary = summary == null
          ? ''
          : ' Hard words completed: ${summary.hardCompleted}/${summary.hardTotal}.';
      _showSnack('Practice completed.$hardSummary');
      unawaited(_stopPractice(completed: true));
    }
  }

  bool _isSkipCommand(String recognized) {
    final normalized = recognized
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) {
      return false;
    }

    return normalized.contains('next word please') ||
        normalized.contains('next word') ||
        normalized.contains('skip word please') ||
        normalized.contains('skip word');
  }

  void _handleSkipWordCommand(String recognized) {
    if (_currentWordIndex >= _scriptWords.length) {
      return;
    }

    final now = DateTime.now();
    if (_lastSkipCommandAt != null &&
        now.difference(_lastSkipCommandAt!) <
            const Duration(milliseconds: 900)) {
      return;
    }
    _lastSkipCommandAt = now;

    final skippedIndex = _currentWordIndex;
    final nextIndex = skippedIndex + 1;
    final completed = nextIndex >= _scriptWords.length;

    if (!mounted) {
      return;
    }

    setState(() {
      _skippedWordIndexes.add(skippedIndex);
      _currentWordIndex = nextIndex;
      _recognizedPreview = recognized;
      _statusText = completed
          ? 'All words processed. Finishing session...'
          : 'Word skipped. Continue with the next highlighted word.';
      if (completed) {
        _lastCompletedSummary = _buildSessionSummary(
          completedWords: nextIndex,
          skippedWordIndexes: _skippedWordIndexes,
        );
      }
    });

    if (completed) {
      final summary = _lastCompletedSummary;
      final hardSummary = summary == null
          ? ''
          : ' Hard words completed: ${summary.hardCompleted}/${summary.hardTotal}.';
      _showSnack('Practice completed.$hardSummary');
      unawaited(_stopPractice(completed: true));
    }
  }

  void _handleSpeechStatus(String status) {
    if (!_isSessionActive || !mounted) {
      return;
    }

    if (status == 'done' || status == 'notListening') {
      _resumeListeningTimer?.cancel();
      _resumeListeningTimer = Timer(const Duration(milliseconds: 320), () {
        unawaited(_resumeListening());
      });
    }
  }

  Future<void> _resumeListening() async {
    if (_isRestarting || !_isSessionActive || _isBusy) {
      return;
    }

    if (_speechService.isListening) {
      return;
    }

    _isRestarting = true;
    try {
      final started = await _speechService
          .startListening(
            onResult: _onSpeechResult,
            listenFor: const Duration(minutes: 8),
            pauseFor: _pauseTolerance,
            localeId: _activeLocaleId,
          )
          .timeout(_speechStartTimeout, onTimeout: () => false);

      if (!started || !mounted) {
        return;
      }

      setState(() {
        _statusText = 'Listening resumed. Continue reading.';
      });
    } catch (_) {
      _showSnack('Could not resume listening automatically.');
    } finally {
      _isRestarting = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  void _startListeningWatchdog() {
    _listeningWatchdogTimer?.cancel();
    _listeningWatchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      if (!_isSessionActive || _isBusy || _isRestarting) {
        return;
      }
      if (_speechService.isListening) {
        return;
      }
      unawaited(_resumeListening());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  _SessionSummary _buildSessionSummary({
    required int completedWords,
    required Set<int> skippedWordIndexes,
  }) {
    final clamped = completedWords.clamp(0, _scriptWords.length).toInt();
    final completedWordsList = <_ScriptWord>[];
    for (var index = 0; index < clamped; index++) {
      if (skippedWordIndexes.contains(index)) {
        continue;
      }
      completedWordsList.add(_scriptWords[index]);
    }
    final easyWordsCompleted = _wordsByDifficulty(
      words: completedWordsList,
      difficulty: _WordDifficulty.easy,
    );
    final moderateWordsCompleted = _wordsByDifficulty(
      words: completedWordsList,
      difficulty: _WordDifficulty.moderate,
    );
    final hardWordsCompleted = _wordsByDifficulty(
      words: completedWordsList,
      difficulty: _WordDifficulty.hard,
    );
    final easyTotal = _scriptWords
        .where((word) => word.difficulty == _WordDifficulty.easy)
        .length;
    final moderateTotal = _scriptWords
        .where((word) => word.difficulty == _WordDifficulty.moderate)
        .length;
    final hardTotal = _scriptWords
        .where((word) => word.difficulty == _WordDifficulty.hard)
        .length;

    return _SessionSummary(
      sessionTitle: _selectedScript.title,
      matchedWords: clamped,
      totalWords: _scriptWords.length,
      easyWordsCompleted: easyWordsCompleted,
      moderateWordsCompleted: moderateWordsCompleted,
      hardWordsCompleted: hardWordsCompleted,
      easyTotal: easyTotal,
      moderateTotal: moderateTotal,
      hardTotal: hardTotal,
      elapsed: _elapsed,
    );
  }

  List<String> _wordsByDifficulty({
    required List<_ScriptWord> words,
    required _WordDifficulty difficulty,
  }) {
    return words
        .where((word) => word.difficulty == difficulty)
        .map((word) => word.raw)
        .toList(growable: false);
  }

  int _calculateNextWordIndex({
    required List<String> heardTokens,
    required int startIndex,
  }) {
    if (startIndex >= _scriptWords.length || heardTokens.isEmpty) {
      return startIndex;
    }

    final tokens = heardTokens.length > _matchScanWindow
        ? heardTokens.sublist(heardTokens.length - _matchScanWindow)
        : heardTokens;

    var expectedIndex = startIndex;
    var tokenCursor = 0;

    while (expectedIndex < _scriptWords.length && tokenCursor < tokens.length) {
      final expected = _scriptWords[expectedIndex].normalized;
      var foundAt = -1;

      for (var i = tokenCursor; i < tokens.length; i++) {
        if (_isTokenMatch(tokens[i], expected)) {
          foundAt = i;
          break;
        }
      }

      if (foundAt == -1) {
        break;
      }

      expectedIndex++;
      tokenCursor = foundAt + 1;
    }

    return expectedIndex;
  }

  bool _isTokenMatch(String spoken, String expected) {
    if (spoken == expected) {
      return true;
    }

    final spokenPhonetic = _phoneticNormalize(spoken);
    final expectedPhonetic = _phoneticNormalize(expected);

    if (spokenPhonetic == expectedPhonetic) {
      return true;
    }

    if (spokenPhonetic.length <= 2 || expectedPhonetic.length <= 2) {
      return false;
    }

    final distance = _levenshteinDistance(spokenPhonetic, expectedPhonetic);
    final allowedDistance = expectedPhonetic.length >= 8 ? 2 : 1;
    return distance <= allowedDistance;
  }

  String _phoneticNormalize(String value) {
    var normalized = value.toLowerCase();
    normalized = normalized
        .replaceAll('ph', 'f')
        .replaceAll('qu', 'k')
        .replaceAll('ck', 'k')
        .replaceAll('c', 'k')
        .replaceAll('x', 'ks')
        .replaceAll('z', 's')
        .replaceAll('v', 'b')
        .replaceAll('th', 't')
        .replaceAll('oo', 'u')
        .replaceAll('ee', 'i');
    normalized = normalized.replaceAll(RegExp(r'(.)\1+'), r'$1');
    return normalized;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }

    final previous = List<int>.generate(b.length + 1, (index) => index);
    final current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      final aChar = a.codeUnitAt(i - 1);

      for (var j = 1; j <= b.length; j++) {
        final cost = aChar == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }

      for (var j = 0; j <= b.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous[b.length];
  }

  List<String> _normalizedTokens(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map(_normalizeWord)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static List<_ScriptWord> _buildScriptWords(String text) {
    final rawTokens = text.split(RegExp(r'\s+'));
    final words = <_ScriptWord>[];

    for (final raw in rawTokens) {
      final normalized = _normalizeWord(raw);
      if (normalized.isEmpty) {
        continue;
      }
      words.add(
        _ScriptWord(
          raw: raw,
          normalized: normalized,
          difficulty: _classifyWordDifficulty(normalized),
        ),
      );
    }
    return words;
  }

  static _WordDifficulty _classifyWordDifficulty(String normalized) {
    final length = normalized.length;
    final syllables = _estimateSyllables(normalized);

    if (length >= 9 || syllables >= 4) {
      return _WordDifficulty.hard;
    }
    if (length >= 6 || syllables >= 3) {
      return _WordDifficulty.moderate;
    }
    return _WordDifficulty.easy;
  }

  static int _estimateSyllables(String word) {
    if (word.isEmpty) {
      return 0;
    }

    var normalized = word.toLowerCase();
    if (normalized.length > 2 && normalized.endsWith('e')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    final vowels = RegExp(r'[aeiouy]');
    var count = 0;
    var previousIsVowel = false;

    for (var i = 0; i < normalized.length; i++) {
      final isVowel = vowels.hasMatch(normalized[i]);
      if (isVowel && !previousIsVowel) {
        count++;
      }
      previousIsVowel = isVowel;
    }

    return count == 0 ? 1 : count;
  }

  static String _normalizeWord(String raw) {
    final lower = raw.toLowerCase().trim();
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _formatElapsed(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final totalWords = _scriptWords.length;
    final matchedWords = _currentWordIndex.clamp(0, totalWords);
    final progress = totalWords == 0 ? 0.0 : matchedWords / totalWords;
    final currentWord = matchedWords < totalWords
        ? _scriptWords[matchedWords].raw
        : 'Completed';

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Session')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Practice Script',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _practiceScripts.map((script) {
                  return ChoiceChip(
                    label: Text(script.title),
                    selected: script.id == _selectedScript.id,
                    onSelected: (_) => _selectScript(script),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              _SessionInfoCard(
                topic: _selectedScript.title,
                targetWords: _selectedScript.targetWords,
                elapsed: _formatElapsed(_elapsed),
                status: _statusText,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSessionActive ? null : _startPractice,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _isBusy && !_isSessionActive
                            ? 'Starting...'
                            : 'Start Practice',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isSessionActive ? _stopPractice : null,
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: Text(
                        _isBusy && _isSessionActive
                            ? 'Stopping...'
                            : 'Stop Practice',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _resetPractice,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Progress: $matchedWords / $totalWords words',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2A5578),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: const Color(0xFFE4EFFA),
              ),
              const SizedBox(height: 10),
              Text(
                'Current Target Word: $currentWord',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_recognizedPreview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Heard: $_recognizedPreview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5A7690),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Read the Script (word lights up only when matched)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DifficultyLegendChip(
                    label: 'Easy',
                    color: Color(0xFF2E7D32),
                  ),
                  _DifficultyLegendChip(
                    label: 'Moderate',
                    color: Color(0xFFE0A800),
                  ),
                  _DifficultyLegendChip(
                    label: 'Hard',
                    color: Color(0xFFC62828),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Teleprompter mode: read the center highlighted lane. Tip: say "next word please" to skip and mark X.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5A7690),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _WordTrackBoard(
                words: _scriptWords,
                currentIndex: matchedWords,
                skippedWordIndexes: _skippedWordIndexes,
              ),
              if (!_isSessionActive && _lastCompletedSummary != null) ...[
                const SizedBox(height: 14),
                _SessionCompletionCard(
                  summary: _lastCompletedSummary!,
                  elapsedLabel: _formatElapsed(_lastCompletedSummary!.elapsed),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({
    required this.topic,
    required this.targetWords,
    required this.elapsed,
    required this.status,
  });

  final String topic;
  final int targetWords;
  final String elapsed;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F86D8), Color(0xFF52ACEF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tag: $targetWords words  |  Time: $elapsed',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyLegendChip extends StatelessWidget {
  const _DifficultyLegendChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label word',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCompletionCard extends StatelessWidget {
  const _SessionCompletionCard({
    required this.summary,
    required this.elapsedLabel,
  });

  final _SessionSummary summary;
  final String elapsedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCDE2F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF123B5C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.sessionTitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF42627D),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Overall matched: ${summary.matchedWords} / ${summary.totalWords} | Time: $elapsedLabel',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5B7892),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 780;
              if (compact) {
                return Column(
                  children: [
                    _DifficultyWordsBox(
                      label: 'Easy',
                      accentColor: const Color(0xFF2E7D32),
                      completed: summary.easyCompleted,
                      total: summary.easyTotal,
                      words: summary.easyWordsCompleted,
                    ),
                    const SizedBox(height: 10),
                    _DifficultyWordsBox(
                      label: 'Moderate',
                      accentColor: const Color(0xFFE0A800),
                      completed: summary.moderateCompleted,
                      total: summary.moderateTotal,
                      words: summary.moderateWordsCompleted,
                    ),
                    const SizedBox(height: 10),
                    _DifficultyWordsBox(
                      label: 'Hard',
                      accentColor: const Color(0xFFC62828),
                      completed: summary.hardCompleted,
                      total: summary.hardTotal,
                      words: summary.hardWordsCompleted,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DifficultyWordsBox(
                      label: 'Easy',
                      accentColor: const Color(0xFF2E7D32),
                      completed: summary.easyCompleted,
                      total: summary.easyTotal,
                      words: summary.easyWordsCompleted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DifficultyWordsBox(
                      label: 'Moderate',
                      accentColor: const Color(0xFFE0A800),
                      completed: summary.moderateCompleted,
                      total: summary.moderateTotal,
                      words: summary.moderateWordsCompleted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DifficultyWordsBox(
                      label: 'Hard',
                      accentColor: const Color(0xFFC62828),
                      completed: summary.hardCompleted,
                      total: summary.hardTotal,
                      words: summary.hardWordsCompleted,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DifficultyWordsBox extends StatelessWidget {
  const _DifficultyWordsBox({
    required this.label,
    required this.accentColor,
    required this.completed,
    required this.total,
    required this.words,
  });

  final String label;
  final Color accentColor;
  final int completed;
  final int total;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ($completed/$total)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: accentColor.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (words.isEmpty)
            Text(
              'No matched words yet.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6E889F)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: words.map((word) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    word,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: accentColor.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _WordTrackBoard extends StatefulWidget {
  const _WordTrackBoard({
    required this.words,
    required this.currentIndex,
    required this.skippedWordIndexes,
  });

  final List<_ScriptWord> words;
  final int currentIndex;
  final Set<int> skippedWordIndexes;

  @override
  State<_WordTrackBoard> createState() => _WordTrackBoardState();
}

class _WordTrackBoardState extends State<_WordTrackBoard> {
  static const double _boardHeight = 290;
  static const double _boardHorizontalPadding = 16;
  static const double _boardVerticalPadding = 18;
  static const double _lineHeight = 60;
  static const double _focusLaneHeight = 52;

  final ScrollController _scrollController = ScrollController();
  List<_TeleprompterLine> _lines = const [];
  double _lastFocusPosition = 0;

  @override
  void initState() {
    super.initState();
    _rebuildLines();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScrollToFocusedLine(animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant _WordTrackBoard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wordsChanged =
        widget.words.length != oldWidget.words.length ||
        !identical(widget.words, oldWidget.words);
    if (wordsChanged) {
      _rebuildLines();
    }

    final currentChanged = widget.currentIndex != oldWidget.currentIndex;
    final skippedChanged =
        widget.skippedWordIndexes.length != oldWidget.skippedWordIndexes.length;
    if (!currentChanged && !wordsChanged && !skippedChanged) {
      return;
    }

    final focusPosition = _focusScrollPosition();
    final delta = (focusPosition - _lastFocusPosition).abs();
    final shouldAnimate = delta > 0.001;
    _lastFocusPosition = focusPosition;
    _syncScrollToFocusedLine(
      animated: shouldAnimate,
      focusPosition: focusPosition,
      delta: delta,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuildLines() {
    _lines = _buildLines(widget.words);
    _lastFocusPosition = _focusScrollPosition();
  }

  int _focusWordIndex() {
    if (widget.words.isEmpty) {
      return 0;
    }
    final clampedCurrent = widget.currentIndex
        .clamp(0, widget.words.length)
        .toInt();
    if (clampedCurrent >= widget.words.length) {
      return widget.words.length - 1;
    }
    return clampedCurrent;
  }

  int _focusLineIndex() {
    final focusWordIndex = _focusWordIndex();
    return _findLineIndexForWord(lines: _lines, wordIndex: focusWordIndex);
  }

  double _focusScrollPosition() {
    if (_lines.isEmpty) {
      return 0;
    }
    final focusWordIndex = _focusWordIndex();
    final lineIndex = _findLineIndexForWord(
      lines: _lines,
      wordIndex: focusWordIndex,
    );
    return lineIndex.toDouble();
  }

  void _syncScrollToFocusedLine({
    required bool animated,
    double? focusPosition,
    double delta = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _lines.isEmpty) {
        return;
      }
      final resolvedPosition = focusPosition ?? _focusScrollPosition();
      final target = _targetOffsetForPosition(resolvedPosition);
      if (animated) {
        final durationMs = (150 + (delta * 130)).clamp(150, 420).round();
        _scrollController.animateTo(
          target,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeInOutCubic,
        );
        return;
      }
      _scrollController.jumpTo(target);
    });
  }

  double _targetOffsetForPosition(double linePosition) {
    if (!_scrollController.hasClients) {
      return 0;
    }
    final maxOffset = _scrollController.position.maxScrollExtent;
    final lineOffset = linePosition * _lineHeight;
    return lineOffset.clamp(0, maxOffset).toDouble();
  }

  double _leadingInset() {
    final viewportHeight = _boardHeight - (_boardVerticalPadding * 2);
    return ((viewportHeight - _lineHeight) / 2).clamp(0, 120).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return const SizedBox.shrink();
    }

    final clampedCurrent = widget.currentIndex
        .clamp(0, widget.words.length)
        .toInt();
    final focusLineIndex = _focusLineIndex();
    final laneTop = (_boardHeight - _focusLaneHeight) / 2;

    return Container(
      width: double.infinity,
      height: _boardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1D9DD5), Color(0xFF178AC8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8AD3F8)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _boardHorizontalPadding,
                vertical: _boardVerticalPadding,
              ),
              child: ListView.builder(
                controller: _scrollController,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: _leadingInset()),
                itemCount: _lines.length,
                itemBuilder: (context, lineIndex) {
                  final line = _lines[lineIndex];
                  final distance = (lineIndex - focusLineIndex).abs();
                  final lineOpacity = _lineOpacityByDistance(distance);
                  final lineScale = distance == 0 ? 1.0 : 0.96;

                  return AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    scale: lineScale,
                    child: SizedBox(
                      height: _lineHeight,
                      child: Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          text: TextSpan(
                            children: _buildLineSpans(
                              line: line,
                              lineOpacity: lineOpacity,
                              currentWordIndex: clampedCurrent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: laneTop,
            child: IgnorePointer(
              child: Container(
                height: _focusLaneHeight,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: laneTop + ((_focusLaneHeight - 24) / 2),
            child: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white70,
            ),
          ),
          Positioned(
            right: 8,
            top: laneTop + ((_focusLaneHeight - 24) / 2),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: laneTop + 4,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF178AC8).withValues(alpha: 0.64),
                      const Color(0xFF178AC8).withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: laneTop + _focusLaneHeight - 4,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF178AC8).withValues(alpha: 0.20),
                      const Color(0xFF178AC8).withValues(alpha: 0.64),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TeleprompterLine> _buildLines(List<_ScriptWord> sourceWords) {
    final lines = <_TeleprompterLine>[];
    var start = 0;
    while (start < sourceWords.length) {
      var endExclusive = start;
      var charCount = 0;
      while (endExclusive < sourceWords.length) {
        final word = sourceWords[endExclusive].raw;
        final addLength = (charCount == 0 ? 0 : 1) + word.length;
        final reachedWordLimit = (endExclusive - start) >= 2;
        final reachedCharLimit = charCount + addLength > 20;
        if (endExclusive > start && (reachedWordLimit || reachedCharLimit)) {
          break;
        }
        charCount += addLength;
        endExclusive++;
      }
      lines.add(
        _TeleprompterLine(startIndex: start, endIndex: endExclusive - 1),
      );
      start = endExclusive;
    }
    return lines;
  }

  int _findLineIndexForWord({
    required List<_TeleprompterLine> lines,
    required int wordIndex,
  }) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (wordIndex >= line.startIndex && wordIndex <= line.endIndex) {
        return i;
      }
    }
    return lines.isEmpty ? 0 : lines.length - 1;
  }

  double _lineOpacityByDistance(int distance) {
    if (distance <= 0) {
      return 1;
    }
    if (distance == 1) {
      return 0.56;
    }
    if (distance == 2) {
      return 0.38;
    }
    if (distance == 3) {
      return 0.24;
    }
    return 0.16;
  }

  List<InlineSpan> _buildLineSpans({
    required _TeleprompterLine line,
    required double lineOpacity,
    required int currentWordIndex,
  }) {
    final spans = <InlineSpan>[];
    for (
      var wordIndex = line.startIndex;
      wordIndex <= line.endIndex;
      wordIndex++
    ) {
      if (wordIndex > line.startIndex) {
        spans.add(const TextSpan(text: ' '));
      }
      final word = widget.words[wordIndex];
      final isSkipped = widget.skippedWordIndexes.contains(wordIndex);
      final isMatched = wordIndex < currentWordIndex && !isSkipped;
      final isCurrent =
          wordIndex == currentWordIndex &&
          currentWordIndex < widget.words.length;

      final baseColor = _wordColor(
        difficulty: word.difficulty,
        isMatched: isMatched,
        isCurrent: isCurrent,
        isSkipped: isSkipped,
      ).withValues(alpha: lineOpacity);

      spans.add(
        TextSpan(
          text: isSkipped ? 'X ${word.raw}' : word.raw,
          style: TextStyle(
            color: baseColor,
            fontSize: isCurrent ? 34 : 30,
            height: 1.2,
            fontWeight: isCurrent || isMatched
                ? FontWeight.w700
                : FontWeight.w600,
            decoration: isSkipped
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            decorationColor: baseColor,
          ),
        ),
      );
    }
    return spans;
  }

  Color _wordColor({
    required _WordDifficulty difficulty,
    required bool isMatched,
    required bool isCurrent,
    required bool isSkipped,
  }) {
    if (isSkipped) {
      return const Color(0xFFFF8A80);
    }
    if (isCurrent) {
      return Colors.white;
    }
    if (isMatched) {
      switch (difficulty) {
        case _WordDifficulty.easy:
          return const Color(0xFF94FFB7);
        case _WordDifficulty.moderate:
          return const Color(0xFFFFF19A);
        case _WordDifficulty.hard:
          return const Color(0xFFFFA6A6);
      }
    }
    return const Color(0xFFE8F7FF);
  }
}

class _TeleprompterLine {
  const _TeleprompterLine({required this.startIndex, required this.endIndex});

  final int startIndex;
  final int endIndex;
}

enum _WordDifficulty { easy, moderate, hard }

class _SessionSummary {
  const _SessionSummary({
    required this.sessionTitle,
    required this.matchedWords,
    required this.totalWords,
    required this.easyWordsCompleted,
    required this.moderateWordsCompleted,
    required this.hardWordsCompleted,
    required this.easyTotal,
    required this.moderateTotal,
    required this.hardTotal,
    required this.elapsed,
  });

  final String sessionTitle;
  final int matchedWords;
  final int totalWords;
  final List<String> easyWordsCompleted;
  final List<String> moderateWordsCompleted;
  final List<String> hardWordsCompleted;
  final int easyTotal;
  final int moderateTotal;
  final int hardTotal;
  final Duration elapsed;

  int get easyCompleted => easyWordsCompleted.length;
  int get moderateCompleted => moderateWordsCompleted.length;
  int get hardCompleted => hardWordsCompleted.length;
}

class _PracticeScript {
  const _PracticeScript({
    required this.id,
    required this.title,
    required this.targetWords,
    required this.text,
  });

  final String id;
  final String title;
  final int targetWords;
  final String text;
}

class _ScriptWord {
  const _ScriptWord({
    required this.raw,
    required this.normalized,
    required this.difficulty,
  });

  final String raw;
  final String normalized;
  final _WordDifficulty difficulty;
}
