import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'package:ai_powered_coach_2026/core/constants/firestore_collections.dart';
import 'package:ai_powered_coach_2026/features/progress_tracking/data/speech_session_persistence_service.dart';
import 'package:ai_powered_coach_2026/features/speech_analysis/domain/content_assessment_service.dart';
import 'package:ai_powered_coach_2026/services/speech/recording_service.dart';
import 'package:ai_powered_coach_2026/services/speech/speech_to_text_service.dart';

class SpeechRecordingPage extends StatefulWidget {
  const SpeechRecordingPage({super.key});

  @override
  State<SpeechRecordingPage> createState() => _SpeechRecordingPageState();
}

class _SpeechRecordingPageState extends State<SpeechRecordingPage> {
  final _topicController = TextEditingController();
  final _recordingService = RecordingService();
  final _speechService = SpeechToTextService();
  final _contentAssessmentService = ContentAssessmentService();
  final _persistenceService = SpeechSessionPersistenceService();

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isBusy = false;
  bool _isSessionRunning = false;
  double _speechWaveLevel = 0.12;
  DateTime? _lastSpeechChunkAt;
  String _statusText = 'Tap Start Session to begin.';
  String _transcript = '';
  String _pendingTranscript = '';
  String _committedTranscript = '';
  String? _audioPath;
  String? _savedSessionId;
  _QuickMetrics? _metrics;
  Map<String, dynamic>? _analysisResult;
  Duration _sessionLimit = const Duration(minutes: 3);
  String _sessionLengthLabel = '3 min';
  bool _showLiveTranscript = true;
  bool _autoSaveSessions = true;
  String? _speechLocaleId;
  String _speechLanguageLabel = 'English + Tagalog';
  bool _isRestartingSpeech = false;
  int _currentWordCount = 0;
  int _pendingWordCount = 0;
  bool _autoStopRequested = false;
  static const bool _captureRawAudio = false;
  static const int _topicMaxLength = 60;
  static const int _maxSessionWords = 500;
  static const _transcriptUpdateInterval = Duration(milliseconds: 90);
  static const _waveUpdateInterval = Duration(milliseconds: 100);
  static const _speechStartTimeout = Duration(seconds: 8);
  static const _speechInitTimeout = Duration(seconds: 6);
  static const _speechLocaleResolveTimeout = Duration(seconds: 3);
  static const List<String> _topicSuggestions = [
    'Job Interview Introduction',
    'Self Introduction',
    'Class Reporting Summary',
    'Debate Practice',
    'Impromptu Speech',
  ];
  static const Map<String, IconData> _topicSuggestionIcons = {
    'Job Interview Introduction': Icons.business_center_outlined,
    'Self Introduction': Icons.person_outline_rounded,
    'Class Reporting Summary': Icons.school_outlined,
    'Debate Practice': Icons.forum_outlined,
    'Impromptu Speech': Icons.lightbulb_outline_rounded,
  };
  static const List<String> _blockedTerms = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'putang ina',
    'puta',
    'gago',
    'tangina',
    'ulol',
    'bobo',
  ];
  static const List<String> _singleWordFillers = [
    // English fillers
    'um',
    'uh',
    'ah',
    'er',
    'erm',
    'uhm',
    'hmm',
    'mmm',
    'like',
    'actually',
    'basically',
    'literally',
    'anyway',
    'anyways',
    'honestly',
    'seriously',
    'well',
    'so',
    'okay',
    'ok',
    'right',
    'alright',
    'kinda',
    'sorta',
    // Tagalog / Filipino fillers
    'ano',
    'parang',
    'kumbaga',
    'bale',
    'diba',
    'eh',
    'naman',
    'ganun',
    'ganoon',
    'ganyan',
    'ganito',
    'yun',
    'yung',
    'eto',
    'ito',
  ];
  static const List<String> _phraseFillers = [
    // English phrase fillers
    'you know',
    'i mean',
    'kind of',
    'sort of',
    'you know what i mean',
    'at the end of the day',
    'to be honest',
    // Tagalog / Filipino phrase fillers
    'alam mo yun',
    'di ba',
    'hindi ba',
    'kung baga',
    'sa ano',
    'ano kasi',
    'yung ano',
    'parang ano',
  ];
  Timer? _transcriptUpdateTimer;
  Timer? _resumeListeningTimer;
  Timer? _waveUpdateTimer;
  Timer? _speechHealthTimer;
  DateTime? _lastListeningHeartbeatAt;
  int _speechRestartFailures = 0;
  static const _speechPauseFor = Duration(seconds: 10);
  static const _speechReconnectDelay = Duration(milliseconds: 320);
  static const _speechHealthCheckInterval = Duration(seconds: 2);
  static const _maxMicDisconnectedDuration = Duration(seconds: 14);
  static const int _maxSpeechRestartFailures = 5;

  @override
  void dispose() {
    _timer?.cancel();
    _transcriptUpdateTimer?.cancel();
    _resumeListeningTimer?.cancel();
    _waveUpdateTimer?.cancel();
    _speechHealthTimer?.cancel();
    _waveUpdateTimer = null;
    _speechHealthTimer = null;
    _topicController.dispose();
    unawaited(_speechService.cancelListening());
    unawaited(_recordingService.dispose());
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_isBusy || _isSessionRunning) {
      return;
    }

    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    _resumeListeningTimer?.cancel();
    _resumeListeningTimer = null;
    _waveUpdateTimer?.cancel();
    _waveUpdateTimer = null;
    _speechHealthTimer?.cancel();
    _speechHealthTimer = null;
    _isRestartingSpeech = false;
    _lastListeningHeartbeatAt = null;
    _speechRestartFailures = 0;
    setState(() {
      _isBusy = true;
      _transcript = '';
      _pendingTranscript = '';
      _committedTranscript = '';
      _currentWordCount = 0;
      _pendingWordCount = 0;
      _speechWaveLevel = 0.12;
      _lastSpeechChunkAt = null;
      _audioPath = null;
      _savedSessionId = null;
      _metrics = null;
      _analysisResult = null;
      _autoStopRequested = false;
      _elapsed = Duration.zero;
      _statusText = 'Preparing microphone...';
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

      if (!kIsWeb) {
        // Keep transcript-first mode stable on Android/iOS.
        // Running raw audio recording and speech recognition simultaneously
        // can block recognition on many physical devices.
        if (_captureRawAudio) {
          final canRecord = await _recordingService.hasPermission();
          if (!canRecord) {
            _showSnack('Recording permission was denied.');
            setState(() {
              _statusText = 'Recording permission was denied.';
            });
            return;
          }
        }
      }

      final runtimeSettings = await _loadSessionRuntimeSettings();
      if (!mounted) return;
      setState(() {
        _sessionLimit = runtimeSettings.sessionLimit;
        _sessionLengthLabel = runtimeSettings.sessionLengthLabel;
        _showLiveTranscript = runtimeSettings.showLiveTranscript;
        _autoSaveSessions = runtimeSettings.autoSaveSessions;
      });

      final available = await _speechService
          .initialize(
            onStatus: (status) {
              _handleSpeechStatus(status);
            },
            onError: (error) {
              _handleSpeechError(error);
            },
          )
          .timeout(_speechInitTimeout, onTimeout: () => false);

      if (!available) {
        _showSnack(
          'Speech recognition is not available on this device/browser.',
        );
        setState(() {
          _statusText = 'Speech recognition unavailable.';
        });
        return;
      }

      final localeConfig = await _resolveSpeechLocaleConfig();
      if (!mounted) return;
      setState(() {
        _speechLocaleId = localeConfig.localeId.isEmpty
            ? null
            : localeConfig.localeId;
        _speechLanguageLabel = localeConfig.label;
      });

      if (!kIsWeb && _captureRawAudio) {
        await _recordingService.startRecording();
      }
      final started = await _startListeningWithFallback(
        onResult: _onSpeechResult,
        listenFor: _sessionLimit + const Duration(seconds: 35),
        pauseFor: _speechPauseFor,
      );
      if (!started) {
        throw StateError('Speech recognition did not start.');
      }

      _markListeningHeartbeat();
      _startTimer();
      if (!mounted) return;
      setState(() {
        _isSessionRunning = true;
        _statusText =
            'Listening... keep speaking naturally. Auto-stop at $_sessionLengthLabel.';
      });
      _startWaveUpdates();
      _startSpeechHealthWatchdog();
    } catch (error, stackTrace) {
      debugPrint('Start session failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _stopSpeechHealthWatchdog();
      _stopWaveUpdates();
      _showSnack(
        kIsWeb
            ? 'Failed to start session. Allow mic in browser permissions and retry.'
            : 'Failed to start recording session. Try again.',
      );
      if (mounted) {
        setState(() {
          _statusText = 'Could not start session.';
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

  Future<void> _stopSession({String? completionReason}) async {
    if (_isBusy || !_isSessionRunning) {
      return;
    }

    var stoppedSuccessfully = false;
    setState(() {
      _isBusy = true;
      _statusText = 'Finalizing your session...';
    });

    try {
      await _speechService.stopListening();
      _stopSpeechHealthWatchdog();
      final latestTranscript = _sanitizeTranscriptChunk(_latestTranscript());
      String? path;
      if (!kIsWeb && _captureRawAudio) {
        path = await _recordingService.stopRecording();
      }
      _stopTimer();
      final metrics = _calculateMetrics(latestTranscript, _elapsed);

      if (metrics.words == 0) {
        if (!mounted) return;
        setState(() {
          _transcript = latestTranscript;
          _pendingTranscript = latestTranscript;
          _committedTranscript = latestTranscript;
          _currentWordCount = 0;
          _pendingWordCount = 0;
          _audioPath = path;
          _savedSessionId = null;
          _metrics = null;
          _analysisResult = null;
          _isSessionRunning = false;
          _statusText =
              'No speech detected. Session was not saved. Please try again.';
        });
        _stopWaveUpdates();
        _showSnack('No speech detected. Session not saved.');
        stoppedSuccessfully = true;
        return;
      }

      final analysis = _buildAnalysisResult(
        metrics,
        transcript: latestTranscript,
      );
      String? savedSessionId;
      if (_autoSaveSessions) {
        try {
          setState(() {
            _statusText = 'Saving session to cloud...';
          });

          savedSessionId = await _persistenceService.saveSessionWithAnalysis(
            topic: _topicController.text.trim(),
            transcript: latestTranscript,
            durationSec: _elapsed.inSeconds,
            analysis: analysis,
          );
        } catch (_) {
          if (mounted) {
            _showSnack(
              'Session analyzed but not saved. Update Firestore rules then try again.',
            );
          }
        }
      }

      final enrichedAnalysis = {...analysis, 'sessionId': savedSessionId};
      final defaultStatus = savedSessionId == null
          ? (_autoSaveSessions
                ? 'Session captured locally. Review your quick feedback below.'
                : 'Session captured. Auto-save is off, so this run stayed local.')
          : 'Session captured and saved. Review your quick feedback below.';
      final resolvedStatus = completionReason ?? defaultStatus;

      if (!mounted) return;
      setState(() {
        _transcript = latestTranscript;
        _pendingTranscript = latestTranscript;
        _committedTranscript = latestTranscript;
        _currentWordCount = metrics.words;
        _pendingWordCount = metrics.words;
        _audioPath = path;
        _savedSessionId = savedSessionId;
        _metrics = metrics;
        _analysisResult = enrichedAnalysis;
        _isSessionRunning = false;
        _statusText = resolvedStatus;
      });
      _stopWaveUpdates();
      stoppedSuccessfully = true;
    } catch (_) {
      _autoStopRequested = false;
      _stopWaveUpdates();
      _showSnack('Failed to stop session. Please try again.');
    } finally {
      _resumeListeningTimer?.cancel();
      _resumeListeningTimer = null;
      _isRestartingSpeech = false;
      _stopSpeechHealthWatchdog();
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
      if (!stoppedSuccessfully) {
        _autoStopRequested = false;
      }
    }
  }

  void _resetSession() {
    if (_isSessionRunning || _isBusy) {
      return;
    }

    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    _resumeListeningTimer?.cancel();
    _resumeListeningTimer = null;
    _waveUpdateTimer?.cancel();
    _waveUpdateTimer = null;
    _speechHealthTimer?.cancel();
    _speechHealthTimer = null;
    _lastSpeechChunkAt = null;
    _lastListeningHeartbeatAt = null;
    _speechRestartFailures = 0;
    _isRestartingSpeech = false;
    setState(() {
      _elapsed = Duration.zero;
      _transcript = '';
      _pendingTranscript = '';
      _committedTranscript = '';
      _currentWordCount = 0;
      _pendingWordCount = 0;
      _speechWaveLevel = 0.12;
      _audioPath = null;
      _savedSessionId = null;
      _metrics = null;
      _analysisResult = null;
      _autoStopRequested = false;
      _statusText = 'Tap Start Session to begin.';
    });
  }

  Future<bool> _ensureMicrophonePermission() async {
    if (kIsWeb) {
      return true;
    }

    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = _elapsed + const Duration(seconds: 1);
      });

      if (_isSessionRunning &&
          !_isBusy &&
          !_autoStopRequested &&
          _elapsed >= _sessionLimit) {
        _requestAutoStop(
          reason: 'Session limit reached ($_sessionLengthLabel).',
          statusText: 'Session time limit reached. Auto-stopping...',
        );
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _startWaveUpdates() {
    _waveUpdateTimer?.cancel();
    _waveUpdateTimer = Timer.periodic(_waveUpdateInterval, (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final lastChunk = _lastSpeechChunkAt;

      double targetLevel;
      if (!_isSessionRunning) {
        targetLevel = 0.12;
      } else if (lastChunk == null) {
        targetLevel = 0.18;
      } else {
        final silenceMs = now.difference(lastChunk).inMilliseconds;
        if (silenceMs <= 260) {
          targetLevel = 0.95;
        } else if (silenceMs <= 520) {
          targetLevel = 0.74;
        } else if (silenceMs <= 900) {
          targetLevel = 0.5;
        } else {
          targetLevel = 0.2;
        }
      }

      final easedLevel =
          _speechWaveLevel + ((targetLevel - _speechWaveLevel) * 0.28);
      if ((easedLevel - _speechWaveLevel).abs() < 0.01) {
        return;
      }
      setState(() {
        _speechWaveLevel = easedLevel.clamp(0.12, 1.0);
      });
    });
  }

  void _stopWaveUpdates() {
    _waveUpdateTimer?.cancel();
    _waveUpdateTimer = null;
    _lastSpeechChunkAt = null;
    if (!mounted) return;
    setState(() {
      _speechWaveLevel = 0.12;
    });
  }

  void _startSpeechHealthWatchdog() {
    _speechHealthTimer?.cancel();
    _lastListeningHeartbeatAt ??= DateTime.now();
    _speechHealthTimer = Timer.periodic(_speechHealthCheckInterval, (_) {
      _runSpeechHealthCheck();
    });
  }

  void _stopSpeechHealthWatchdog() {
    _speechHealthTimer?.cancel();
    _speechHealthTimer = null;
    _lastListeningHeartbeatAt = null;
    _speechRestartFailures = 0;
  }

  void _markListeningHeartbeat() {
    _lastListeningHeartbeatAt = DateTime.now();
    _speechRestartFailures = 0;
  }

  void _runSpeechHealthCheck() {
    if (!mounted ||
        !_isSessionRunning ||
        _isBusy ||
        _autoStopRequested ||
        _isRestartingSpeech) {
      return;
    }

    if (_speechService.isListening) {
      _markListeningHeartbeat();
      return;
    }

    final lastHeartbeat = _lastListeningHeartbeatAt;
    if (lastHeartbeat != null &&
        DateTime.now().difference(lastHeartbeat) >=
            _maxMicDisconnectedDuration) {
      _requestAutoStop(
        reason: 'Microphone disconnected unexpectedly.',
        statusText: 'Microphone disconnected. Auto-stopping session...',
      );
      return;
    }

    if (_resumeListeningTimer?.isActive ?? false) {
      return;
    }

    _resumeListeningTimer = Timer(_speechReconnectDelay, () {
      unawaited(_resumeListening());
    });
  }

  _QuickMetrics _calculateMetrics(String transcript, Duration elapsed) {
    final words = _countWords(transcript);
    final fillerWords = _countFillerWords(transcript);
    final seconds = elapsed.inSeconds == 0 ? 1 : elapsed.inSeconds;
    final wpm = words == 0 ? 0 : ((words * 60) / seconds).round();

    String paceLabel;
    if (words == 0) {
      paceLabel = 'No speech';
    } else if (wpm < 110) {
      paceLabel = 'Slow';
    } else if (wpm <= 160) {
      paceLabel = 'Good Pace';
    } else {
      paceLabel = 'Fast';
    }

    var confidence = 0;
    if (words > 0) {
      final fillerRatio = fillerWords / words;
      confidence = (95 - (fillerRatio * 150)).round().clamp(45, 98).toInt();
    }

    return _QuickMetrics(
      words: words,
      fillerWords: fillerWords,
      wordsPerMinute: wpm,
      paceLabel: paceLabel,
      confidenceEstimate: confidence,
    );
  }

  Map<String, dynamic> _buildAnalysisResult(
    _QuickMetrics metrics, {
    required String transcript,
  }) {
    final contentAssessment = _contentAssessmentService.assess(
      transcript: transcript,
      topic: _topicController.text.trim(),
    );
    final paceScore = _paceScore(metrics.wordsPerMinute);
    final fillerPenalty = (metrics.fillerWords * 5).clamp(0, 35);
    final fillerScore = (100 - fillerPenalty).toInt();
    final deliveryScore =
        ((paceScore * 0.4) +
                (fillerScore * 0.35) +
                (metrics.confidenceEstimate * 0.25))
            .round()
            .clamp(0, 100)
            .toInt();

    final contentScore = contentAssessment.contentScore;
    final overallScore = ((deliveryScore * 0.55) + (contentScore * 0.45))
        .round()
        .clamp(0, 100)
        .toInt();

    final strengths = <String>[...contentAssessment.strengths];
    final improvements = <String>[...contentAssessment.improvements];

    if (metrics.wordsPerMinute >= 110 && metrics.wordsPerMinute <= 160) {
      strengths.add('Your speaking pace is in the ideal range.');
    } else {
      improvements.add(
        metrics.wordsPerMinute < 110
            ? 'Try speaking a bit faster to maintain audience engagement.'
            : 'Slow down slightly to improve clarity.',
      );
    }

    if (metrics.fillerWords <= 2) {
      strengths.add('Great control of filler words.');
    } else {
      improvements.add(
        'Reduce filler words by pausing briefly before key points.',
      );
    }

    if (metrics.words >= 25) {
      strengths.add('You provided enough verbal content for analysis.');
    } else {
      improvements.add(
        'Add more supporting details to strengthen your message.',
      );
    }

    if (metrics.confidenceEstimate >= 80) {
      strengths.add('Your confidence estimate looks strong.');
    } else {
      improvements.add(
        'Practice with slower breathing and clear sentence starts.',
      );
    }

    if (strengths.isEmpty) {
      strengths.add('You completed the speaking session successfully.');
    }
    if (improvements.isEmpty) {
      improvements.add(
        'Maintain consistency and keep practicing daily sessions.',
      );
    }

    return {
      'overallScore': overallScore,
      'deliveryScore': deliveryScore,
      'contentScore': contentScore,
      'coherenceScore': contentAssessment.coherenceScore,
      'relevanceScore': contentAssessment.relevanceScore,
      'grammarScore': contentAssessment.grammarScore,
      'effectivenessScore': contentAssessment.effectivenessScore,
      'confidenceEstimate': metrics.confidenceEstimate,
      'words': metrics.words,
      'wordsPerMinute': metrics.wordsPerMinute,
      'paceLabel': metrics.paceLabel,
      'fillerWords': metrics.fillerWords,
      'detectedFillers': _extractTopFillers(transcript, limit: 5),
      'topic': _topicController.text.trim(),
      'transcript': transcript,
      'strengths': strengths,
      'improvements': improvements,
    };
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final rawChunk = result.recognizedWords.trim();
    if (rawChunk.isEmpty) {
      return;
    }

    final chunk = _sanitizeTranscriptChunk(rawChunk);
    if (chunk.isEmpty) {
      return;
    }
    _markListeningHeartbeat();
    _lastSpeechChunkAt = DateTime.now();
    if (mounted && _isSessionRunning) {
      final chunkWords = _countWords(chunk);
      final burstLevel =
          (0.58 + math.min(0.35, chunkWords * 0.07)) *
          (result.finalResult ? 1.0 : 0.9);
      final clampedBurst = burstLevel.clamp(0.12, 1.0).toDouble();
      if (clampedBurst > _speechWaveLevel + 0.05) {
        setState(() {
          _speechWaveLevel = clampedBurst;
        });
      }
    }

    final mergedTranscript = _mergeTranscript(_committedTranscript, chunk);
    if (result.finalResult) {
      _committedTranscript = mergedTranscript;
    }

    if (mergedTranscript == _pendingTranscript) {
      return;
    }

    _pendingTranscript = mergedTranscript;
    _pendingWordCount = _countWords(mergedTranscript);

    if (_isSessionRunning &&
        !_isBusy &&
        !_autoStopRequested &&
        _pendingWordCount >= _maxSessionWords) {
      _requestAutoStop(
        reason: 'Word limit reached ($_maxSessionWords words).',
        statusText: 'Word limit reached. Auto-stopping...',
      );
    }

    if (!_showLiveTranscript) {
      if (!mounted) return;
      if (_currentWordCount == _pendingWordCount) {
        return;
      }
      setState(() {
        _currentWordCount = _pendingWordCount;
      });
      return;
    }

    // Throttle partial UI refreshes so speech feels smoother on mobile.
    if (!result.finalResult) {
      _transcriptUpdateTimer ??= Timer(_transcriptUpdateInterval, () {
        _transcriptUpdateTimer = null;
        if (!mounted) return;
        if (_transcript == _pendingTranscript &&
            _currentWordCount == _pendingWordCount) {
          return;
        }
        setState(() {
          _transcript = _pendingTranscript;
          _currentWordCount = _pendingWordCount;
        });
      });
      return;
    }

    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    if (!mounted ||
        (_transcript == _pendingTranscript &&
            _currentWordCount == _pendingWordCount)) {
      return;
    }
    setState(() {
      _transcript = _pendingTranscript;
      _currentWordCount = _pendingWordCount;
    });
  }

  String _latestTranscript() {
    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    if (_pendingTranscript.trim().isNotEmpty) {
      return _pendingTranscript;
    }
    if (_committedTranscript.trim().isNotEmpty) {
      return _committedTranscript;
    }
    return _transcript;
  }

  int _paceScore(int wpm) {
    if (wpm >= 110 && wpm <= 160) {
      return 95;
    }
    if (wpm >= 90 && wpm <= 180) {
      return 80;
    }
    if (wpm >= 70 && wpm <= 200) {
      return 65;
    }
    return 50;
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final tokens = RegExp(
      r"[A-Za-zÀ-ÖØ-öø-ÿĀ-ž]+(?:['-][A-Za-zÀ-ÖØ-öø-ÿĀ-ž]+)*|\d+",
    ).allMatches(trimmed);
    return tokens.length;
  }

  int _countFillerWords(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }

    String working = text.toLowerCase();
    var count = 0;

    // Count phrase fillers first, then remove them from working text
    // to avoid double-counting their component words.
    for (final phrase in _phraseFillers) {
      final regex = _fillerRegex(phrase);
      final matches = regex.allMatches(working).length;
      if (matches == 0) {
        continue;
      }
      count += matches;
      working = working.replaceAll(regex, ' ');
    }

    // Count single-word fillers after phrase cleanup.
    for (final filler in _singleWordFillers) {
      final regex = _fillerRegex(filler);
      count += regex.allMatches(working).length;
    }
    return count;
  }

  List<Map<String, dynamic>> _extractTopFillers(String text, {int limit = 5}) {
    if (text.trim().isEmpty || limit <= 0) {
      return const [];
    }

    String working = text.toLowerCase();
    final counts = <String, int>{};

    for (final phrase in _phraseFillers) {
      final regex = _fillerRegex(phrase);
      final matches = regex.allMatches(working).length;
      if (matches == 0) {
        continue;
      }
      counts[phrase] = matches;
      working = working.replaceAll(regex, ' ');
    }

    for (final filler in _singleWordFillers) {
      final regex = _fillerRegex(filler);
      final matches = regex.allMatches(working).length;
      if (matches == 0) {
        continue;
      }
      counts[filler] = (counts[filler] ?? 0) + matches;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) {
          return byCount;
        }
        return a.key.compareTo(b.key);
      });

    return sortedEntries
        .take(limit)
        .map((entry) => {'term': entry.key, 'count': entry.value})
        .toList(growable: false);
  }

  RegExp _fillerRegex(String phrase) {
    // Treat space/hyphen/apostrophe variants as the same phrase.
    final words = phrase
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map(RegExp.escape)
        .toList();

    final body = words.join(r"[\s\-']+");
    return RegExp('(^|\\W)$body(?=\\W|\$)');
  }

  String _sanitizeTranscriptChunk(String chunk) {
    var sanitized = chunk;
    for (final blocked in _blockedTerms) {
      final pattern = RegExp(
        '\\b${RegExp.escape(blocked)}\\b',
        caseSensitive: false,
      );
      sanitized = sanitized.replaceAll(pattern, ' ');
    }
    return _normalizeText(sanitized);
  }

  String _normalizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _mergeTranscript(String baseTranscript, String nextChunk) {
    final base = _normalizeText(baseTranscript);
    final next = _normalizeText(nextChunk);

    if (base.isEmpty) return next;
    if (next.isEmpty) return base;
    if (base == next) return base;
    if (next.startsWith(base)) return next;
    if (base.endsWith(next)) return base;

    final baseWords = base.split(' ');
    final nextWords = next.split(' ');
    final maxOverlap = baseWords.length < nextWords.length
        ? baseWords.length
        : nextWords.length;

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final baseSuffix = baseWords.sublist(baseWords.length - overlap);
      final nextPrefix = nextWords.sublist(0, overlap);
      if (listEquals(baseSuffix, nextPrefix)) {
        return [...baseWords, ...nextWords.sublist(overlap)].join(' ');
      }
    }

    return '$base $next';
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;

    if (status == 'listening') {
      _markListeningHeartbeat();
    }

    final mappedStatus = _mapSpeechStatus(status);
    if (mappedStatus != _statusText) {
      setState(() {
        _statusText = mappedStatus;
      });
    }

    final shouldTryResume =
        _isSessionRunning &&
        !_isBusy &&
        !_autoStopRequested &&
        (status == 'done' || status == 'notListening');
    if (!shouldTryResume) {
      return;
    }

    _resumeListeningTimer?.cancel();
    _resumeListeningTimer = Timer(_speechReconnectDelay, () {
      unawaited(_resumeListening());
    });
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    if (_isSessionRunning) {
      setState(() {
        _statusText = 'Mic issue detected. Reconnecting...';
      });
    } else {
      setState(() {
        _statusText = 'Speech recognition error: ${error.errorMsg}';
      });
    }

    final shouldTryResume =
        _isSessionRunning && !_isBusy && !_autoStopRequested;
    if (!shouldTryResume) {
      return;
    }

    _resumeListeningTimer?.cancel();
    _resumeListeningTimer = Timer(_speechReconnectDelay, () {
      unawaited(_resumeListening());
    });
  }

  Future<void> _resumeListening() async {
    if (_isRestartingSpeech ||
        !_isSessionRunning ||
        _isBusy ||
        _autoStopRequested) {
      return;
    }
    if (_speechService.isListening) {
      return;
    }

    _isRestartingSpeech = true;
    try {
      final started = await _startListeningWithFallback(
        onResult: _onSpeechResult,
        listenFor: _sessionLimit + const Duration(seconds: 35),
        pauseFor: _speechPauseFor,
      );
      if (!started) {
        _speechRestartFailures++;
        if (_speechRestartFailures >= _maxSpeechRestartFailures) {
          _requestAutoStop(
            reason:
                'Mic reconnection failed multiple times. Please retry the session.',
            statusText: 'Mic reconnection failed. Auto-stopping session...',
          );
        } else if (mounted) {
          setState(() {
            _statusText = 'Mic paused. Reconnecting...';
          });
        }
        return;
      }
      _markListeningHeartbeat();
      if (!mounted) return;
      setState(() {
        _statusText = 'Listening... keep speaking naturally.';
      });
    } catch (error) {
      debugPrint('Resume listening failed: $error');
    } finally {
      _isRestartingSpeech = false;
    }
  }

  String _mapSpeechStatus(String rawStatus) {
    switch (rawStatus) {
      case 'listening':
        return 'Listening... keep speaking naturally.';
      case 'notListening':
        return 'Mic paused. Reconnecting...';
      case 'done':
        return 'Mic paused. Reconnecting...';
      default:
        return 'Speech status: $rawStatus';
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<_SessionRuntimeSettings> _loadSessionRuntimeSettings() async {
    const fallback = _SessionRuntimeSettings(
      sessionLengthLabel: '3 min',
      sessionLimit: Duration(minutes: 3),
      showLiveTranscript: true,
      autoSaveSessions: true,
    );
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return fallback;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      final rawSettings = data?['settings'];
      if (rawSettings is! Map) {
        return fallback;
      }
      final settings = rawSettings.cast<String, dynamic>();
      final sessionLengthLabel =
          (settings['preferredSessionLength'] as String?) ??
          fallback.sessionLengthLabel;
      final showLiveTranscript =
          (settings['showLiveTranscript'] as bool?) ??
          fallback.showLiveTranscript;
      final autoSaveSessions =
          (settings['autoSaveSessions'] as bool?) ?? fallback.autoSaveSessions;

      return _SessionRuntimeSettings(
        sessionLengthLabel: sessionLengthLabel,
        sessionLimit: _parseSessionLimit(sessionLengthLabel),
        showLiveTranscript: showLiveTranscript,
        autoSaveSessions: autoSaveSessions,
      );
    } catch (error) {
      debugPrint('Could not load session runtime settings: $error');
      return fallback;
    }
  }

  Future<_SpeechLocaleConfig> _resolveSpeechLocaleConfig() async {
    const preferredLocaleIds = ['en_PH', 'fil_PH', 'en_US'];
    try {
      final localeId = await _speechService
          .resolveBestLocale(preferredLocaleIds: preferredLocaleIds)
          .timeout(_speechLocaleResolveTimeout, onTimeout: () => null);
      final resolvedLocale = localeId ?? preferredLocaleIds.first;
      return _SpeechLocaleConfig(
        localeId: resolvedLocale,
        label: _labelFromLocaleId(resolvedLocale),
      );
    } catch (_) {
      return const _SpeechLocaleConfig(localeId: '', label: 'Auto (System)');
    }
  }

  Future<bool> _startListeningWithFallback({
    required SpeechResultHandler onResult,
    required Duration listenFor,
    required Duration pauseFor,
  }) async {
    final preferredLocaleId = _speechLocaleId;

    Future<bool> tryStart(String? localeId) {
      return _speechService
          .startListening(
            onResult: onResult,
            listenFor: listenFor,
            pauseFor: pauseFor,
            localeId: localeId,
          )
          .timeout(_speechStartTimeout, onTimeout: () => false);
    }

    var started = await tryStart(preferredLocaleId);
    if (started) {
      return true;
    }

    if (preferredLocaleId == null || preferredLocaleId.isEmpty) {
      return false;
    }

    started = await tryStart(null);
    if (!started) {
      return false;
    }

    if (mounted) {
      setState(() {
        _speechLocaleId = null;
        _speechLanguageLabel = 'Auto (System)';
      });
    } else {
      _speechLocaleId = null;
      _speechLanguageLabel = 'Auto (System)';
    }
    return true;
  }

  String _labelFromLocaleId(String localeId) {
    final normalized = localeId.toLowerCase();
    if (normalized.startsWith('fil') || normalized.startsWith('tl')) {
      return 'Tagalog';
    }
    if (normalized.startsWith('en_ph')) {
      return 'English + Tagalog';
    }
    if (normalized.startsWith('en')) {
      return 'English';
    }
    return localeId;
  }

  Duration _parseSessionLimit(String sessionLengthLabel) {
    final normalized = sessionLengthLabel.toLowerCase().trim();
    if (normalized.startsWith('1')) {
      return const Duration(minutes: 1);
    }
    if (normalized.startsWith('5')) {
      return const Duration(minutes: 5);
    }
    return const Duration(minutes: 3);
  }

  void _requestAutoStop({required String reason, required String statusText}) {
    if (_autoStopRequested || !_isSessionRunning || _isBusy) {
      return;
    }
    _autoStopRequested = true;
    if (mounted) {
      setState(() {
        _statusText = statusText;
      });
      _showSnack(reason);
    }
    unawaited(_stopSession(completionReason: reason));
  }

  String _buildWordLimitedText(String text, int maxWords) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length <= maxWords) {
      return trimmed;
    }

    return words.sublist(words.length - maxWords).join(' ');
  }

  void _applyTopicSuggestion(String suggestion) {
    if (_isSessionRunning) {
      return;
    }

    _topicController
      ..text = suggestion
      ..selection = TextSelection.collapsed(offset: suggestion.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final analysisResult = _analysisResult;
    final hasTopic = _topicController.text.trim().isNotEmpty;
    final normalizedTopic = _topicController.text.trim().toLowerCase();
    final statusCardTranscriptPreview = !_showLiveTranscript
        ? 'Live transcript is off in Settings.'
        : _transcript.trim().isEmpty
        ? (_isSessionRunning
              ? 'Listening... start speaking and your words will appear here.'
              : 'Transcript preview will appear here during your session.')
        : _buildWordLimitedText(_transcript, _maxSessionWords);
    final startButtonLabel = _isBusy && !_isSessionRunning
        ? 'Starting...'
        : 'Start Session';
    final stopButtonLabel = _isBusy && _isSessionRunning
        ? 'Stopping...'
        : 'Stop Session';

    return Scaffold(
      appBar: AppBar(title: const Text('Speech Recording Session')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session Topic',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _topicController,
                enabled: !_isSessionRunning,
                maxLength: _topicMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Example: Job interview self-introduction',
                  prefixIcon: Icon(Icons.topic_outlined),
                ),
              ),
              if (!_isSessionRunning && !hasTopic) ...[
                const SizedBox(height: 6),
                Text(
                  'Please enter a session topic (ex: Job Interview Intro).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB04141),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Quick Topics',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4E6B85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _topicSuggestions.map((topic) {
                  final isSelected = normalizedTopic == topic.toLowerCase();
                  return _QuickTopicChip(
                    label: topic,
                    icon: _topicSuggestionIcons[topic] ?? Icons.topic_outlined,
                    isSelected: isSelected,
                    onTap: _isSessionRunning
                        ? null
                        : () {
                            _applyTopicSuggestion(topic);
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _StatusCard(
                statusText: _statusText,
                elapsedText: _formatDuration(_elapsed),
                isLive: _isSessionRunning,
                speechActivity: _speechWaveLevel,
                transcriptPreview: statusCardTranscriptPreview,
                showTranscriptPreview: _showLiveTranscript,
                wordCount: _currentWordCount,
                previewWordLimit: _maxSessionWords,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SessionInfoPill(
                    icon: Icons.timer_outlined,
                    label: 'Session Limit',
                    value: _sessionLengthLabel,
                  ),
                  _SessionInfoPill(
                    icon: Icons.sort_by_alpha_rounded,
                    label: 'Words',
                    value: '$_currentWordCount / $_maxSessionWords',
                  ),
                  _SessionInfoPill(
                    icon: Icons.translate_rounded,
                    label: 'Language',
                    value: _speechLanguageLabel,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactButtons = constraints.maxWidth < 390;
                  final startButton = FilledButton.icon(
                    onPressed: (_isSessionRunning || !hasTopic)
                        ? null
                        : _startSession,
                    icon: const Icon(Icons.mic_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(startButtonLabel),
                    ),
                  );
                  final stopButton = FilledButton.tonalIcon(
                    onPressed: _isSessionRunning ? _stopSession : null,
                    icon: const Icon(Icons.stop_circle_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(stopButtonLabel),
                    ),
                  );

                  if (compactButtons) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: startButton),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: stopButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: startButton),
                      const SizedBox(width: 10),
                      Expanded(child: stopButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _resetSession,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset'),
                ),
              ),
              if (metrics != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Quick Delivery Feedback',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF123B5C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardAspectRatio = constraints.maxWidth < 360
                        ? 1.05
                        : constraints.maxWidth < 420
                        ? 1.18
                        : 1.4;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: cardAspectRatio,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        _MetricCard(
                          label: 'Words',
                          value: '${metrics.words}',
                          icon: Icons.notes_rounded,
                        ),
                        _MetricCard(
                          label: 'Pace',
                          value: '${metrics.wordsPerMinute} WPM',
                          hint: metrics.paceLabel,
                          icon: Icons.speed_rounded,
                        ),
                        _MetricCard(
                          label: 'Filler Words',
                          value: '${metrics.fillerWords}',
                          icon: Icons.hearing_disabled_rounded,
                        ),
                        _MetricCard(
                          label: 'Confidence Est.',
                          value: '${metrics.confidenceEstimate}%',
                          icon: Icons.psychology_alt_rounded,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: analysisResult == null
                        ? null
                        : () {
                            context.push(
                              '/analysis-result',
                              extra: analysisResult,
                            );
                          },
                    icon: const Icon(Icons.insights_rounded),
                    label: const Text('View Full Analysis'),
                  ),
                ),
                if (_savedSessionId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Saved session ID: $_savedSessionId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5B7892),
                    ),
                  ),
                ],
              ],
              if (_audioPath != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Audio file path: $_audioPath',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5A7894),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Note: Current feedback is transcript-based. Advanced AI scoring will be added in the next step.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5E7B95)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.statusText,
    required this.elapsedText,
    required this.isLive,
    required this.speechActivity,
    required this.transcriptPreview,
    required this.showTranscriptPreview,
    required this.wordCount,
    required this.previewWordLimit,
  });

  final String statusText;
  final String elapsedText;
  final bool isLive;
  final double speechActivity;
  final String transcriptPreview;
  final bool showTranscriptPreview;
  final int wordCount;
  final int previewWordLimit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(
                isLive
                    ? Icons.fiber_manual_record_rounded
                    : Icons.pause_circle_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 6),
              Text(
                isLive ? 'Live Session' : 'Ready',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                elapsedText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.94),
            ),
          ),
          const SizedBox(height: 10),
          _LiveSpeechWave(isActive: isLive, speechActivity: speechActivity),
          if (showTranscriptPreview) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Preview (up to $previewWordLimit words)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Text(
                        transcriptPreview,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.98),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Words: $wordCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveSpeechWave extends StatefulWidget {
  const _LiveSpeechWave({required this.isActive, required this.speechActivity});

  final bool isActive;
  final double speechActivity;

  @override
  State<_LiveSpeechWave> createState() => _LiveSpeechWaveState();
}

class _LiveSpeechWaveState extends State<_LiveSpeechWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _LiveSpeechWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat();
      return;
    }
    if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final phase = widget.isActive ? _controller.value : 0.0;
              return CustomPaint(
                painter: _LiveSpeechWavePainter(
                  phase: phase,
                  isActive: widget.isActive,
                  speechActivity: widget.speechActivity,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiveSpeechWavePainter extends CustomPainter {
  _LiveSpeechWavePainter({
    required this.phase,
    required this.isActive,
    required this.speechActivity,
  });

  final double phase;
  final bool isActive;
  final double speechActivity;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeBase = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerY = size.height * 0.5;
    final waveTravel = phase * math.pi * 2;
    final activity = isActive
        ? speechActivity.clamp(0.12, 1.0).toDouble()
        : 0.12;

    _drawWave(
      canvas: canvas,
      size: size,
      paint: strokeBase,
      color: Colors.white.withValues(alpha: 0.88),
      strokeWidth: 1.6,
      baseY: centerY,
      amplitude: size.height * 0.14 * activity,
      cycles: 1.55,
      phaseShift: waveTravel,
    );

    _drawWave(
      canvas: canvas,
      size: size,
      paint: strokeBase,
      color: Colors.white.withValues(alpha: 0.42),
      strokeWidth: 1.2,
      baseY: centerY - 7,
      amplitude: size.height * 0.1 * activity,
      cycles: 1.25,
      phaseShift: waveTravel * 0.85 + 1.1,
    );

    _drawWave(
      canvas: canvas,
      size: size,
      paint: strokeBase,
      color: Colors.white.withValues(alpha: 0.28),
      strokeWidth: 1.0,
      baseY: centerY + 7,
      amplitude: size.height * 0.085 * activity,
      cycles: 1.1,
      phaseShift: waveTravel * 1.2 + 2.1,
    );
  }

  void _drawWave({
    required Canvas canvas,
    required Size size,
    required Paint paint,
    required Color color,
    required double strokeWidth,
    required double baseY,
    required double amplitude,
    required double cycles,
    required double phaseShift,
  }) {
    final path = Path();
    var hasStarted = false;
    for (var x = 0.0; x <= size.width; x += 2) {
      final progress = x / size.width;
      final y =
          baseY +
          (amplitude *
              math.sin((progress * cycles * math.pi * 2) + phaseShift));
      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }

    final wavePaint = paint
      ..color = color
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _LiveSpeechWavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isActive != isActive ||
        oldDelegate.speechActivity != speechActivity;
  }
}

class _SessionInfoPill extends StatelessWidget {
  const _SessionInfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD2E6F9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF246A9D)),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF2B5578),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTopicChip extends StatelessWidget {
  const _QuickTopicChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected ? const Color(0xFF1E82D2) : Colors.white;
    final borderColor = isSelected
        ? const Color(0xFF1E82D2)
        : const Color(0xFFD2E6F9);
    final labelColor = isSelected ? Colors.white : const Color(0xFF284E70);
    final iconColor = isSelected ? Colors.white : const Color(0xFF2A7CBD);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x2A1E82D2),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD3E6F8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1E79C0)),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5A7793),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF123A5B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF42739A)),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickMetrics {
  const _QuickMetrics({
    required this.words,
    required this.fillerWords,
    required this.wordsPerMinute,
    required this.paceLabel,
    required this.confidenceEstimate,
  });

  final int words;
  final int fillerWords;
  final int wordsPerMinute;
  final String paceLabel;
  final int confidenceEstimate;
}

class _SpeechLocaleConfig {
  const _SpeechLocaleConfig({required this.localeId, required this.label});

  final String localeId;
  final String label;
}

class _SessionRuntimeSettings {
  const _SessionRuntimeSettings({
    required this.sessionLengthLabel,
    required this.sessionLimit,
    required this.showLiveTranscript,
    required this.autoSaveSessions,
  });

  final String sessionLengthLabel;
  final Duration sessionLimit;
  final bool showLiveTranscript;
  final bool autoSaveSessions;
}
