import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

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
  String _statusText = 'Tap Start Session to begin.';
  String _transcript = '';
  String _pendingTranscript = '';
  String? _audioPath;
  String? _savedSessionId;
  _QuickMetrics? _metrics;
  Map<String, dynamic>? _analysisResult;
  static const bool _captureRawAudio = false;
  static const _transcriptUpdateInterval = Duration(milliseconds: 140);
  Timer? _transcriptUpdateTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _transcriptUpdateTimer?.cancel();
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
    setState(() {
      _isBusy = true;
      _transcript = '';
      _pendingTranscript = '';
      _audioPath = null;
      _savedSessionId = null;
      _metrics = null;
      _analysisResult = null;
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

      final available = await _speechService.initialize(
        onStatus: (status) {
          if (!mounted) return;
          final mappedStatus = _mapSpeechStatus(status);
          if (mappedStatus == _statusText) {
            return;
          }
          setState(() {
            _statusText = mappedStatus;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _statusText = 'Speech recognition error: ${error.errorMsg}';
          });
        },
      );

      if (!available) {
        _showSnack(
          'Speech recognition is not available on this device/browser.',
        );
        setState(() {
          _statusText = 'Speech recognition unavailable.';
        });
        return;
      }

      if (!kIsWeb && _captureRawAudio) {
        await _recordingService.startRecording();
      }
      final started = await _speechService.startListening(
        onResult: _onSpeechResult,
      );
      if (!started) {
        throw StateError('Speech recognition did not start.');
      }

      _startTimer();
      if (!mounted) return;
      setState(() {
        _isSessionRunning = true;
        _statusText = 'Listening... keep speaking naturally.';
      });
    } catch (error, stackTrace) {
      debugPrint('Start session failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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

  Future<void> _stopSession() async {
    if (_isBusy || !_isSessionRunning) {
      return;
    }

    setState(() {
      _isBusy = true;
      _statusText = 'Finalizing your session...';
    });

    try {
      await _speechService.stopListening();
      final latestTranscript = _latestTranscript();
      String? path;
      if (!kIsWeb && _captureRawAudio) {
        path = await _recordingService.stopRecording();
      }
      _stopTimer();
      final metrics = _calculateMetrics(latestTranscript, _elapsed);
      final analysis = _buildAnalysisResult(
        metrics,
        transcript: latestTranscript,
      );
      String? savedSessionId;
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

      final enrichedAnalysis = {...analysis, 'sessionId': savedSessionId};

      if (!mounted) return;
      setState(() {
        _transcript = latestTranscript;
        _pendingTranscript = latestTranscript;
        _audioPath = path;
        _savedSessionId = savedSessionId;
        _metrics = metrics;
        _analysisResult = enrichedAnalysis;
        _isSessionRunning = false;
        _statusText = savedSessionId == null
            ? 'Session captured locally. Review your quick feedback below.'
            : 'Session captured and saved. Review your quick feedback below.';
      });
    } catch (_) {
      _showSnack('Failed to stop session. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _resetSession() {
    if (_isSessionRunning || _isBusy) {
      return;
    }

    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    setState(() {
      _elapsed = Duration.zero;
      _transcript = '';
      _pendingTranscript = '';
      _audioPath = null;
      _savedSessionId = null;
      _metrics = null;
      _analysisResult = null;
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
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  _QuickMetrics _calculateMetrics(String transcript, Duration elapsed) {
    final words = _countWords(transcript);
    final fillerWords = _countFillerWords(transcript);
    final seconds = elapsed.inSeconds == 0 ? 1 : elapsed.inSeconds;
    final wpm = ((words * 60) / seconds).round();

    String paceLabel;
    if (wpm < 110) {
      paceLabel = 'Slow';
    } else if (wpm <= 160) {
      paceLabel = 'Good Pace';
    } else {
      paceLabel = 'Fast';
    }

    final fillerRatio = words == 0 ? 0.0 : fillerWords / words;
    var confidence = (95 - (fillerRatio * 150)).round();
    confidence = confidence.clamp(45, 98).toInt();

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
      'topic': _topicController.text.trim(),
      'transcript': transcript,
      'strengths': strengths,
      'improvements': improvements,
    };
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final recognizedWords = result.recognizedWords;
    if (recognizedWords == _pendingTranscript) {
      return;
    }
    _pendingTranscript = recognizedWords;

    // Throttle partial UI refreshes so speech feels smoother on mobile.
    if (!result.finalResult) {
      _transcriptUpdateTimer ??= Timer(_transcriptUpdateInterval, () {
        _transcriptUpdateTimer = null;
        if (!mounted) return;
        if (_transcript == _pendingTranscript) return;
        setState(() {
          _transcript = _pendingTranscript;
        });
      });
      return;
    }

    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    if (!mounted || _transcript == _pendingTranscript) {
      return;
    }
    setState(() {
      _transcript = _pendingTranscript;
    });
  }

  String _latestTranscript() {
    _transcriptUpdateTimer?.cancel();
    _transcriptUpdateTimer = null;
    return _pendingTranscript.trim().isNotEmpty
        ? _pendingTranscript
        : _transcript;
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
    return trimmed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  int _countFillerWords(String text) {
    if (text.trim().isEmpty) {
      return 0;
    }

    final lower = text.toLowerCase();
    const fillers = [
      'um',
      'uh',
      'like',
      'actually',
      'basically',
      'literally',
      'you know',
    ];

    var count = 0;
    for (final filler in fillers) {
      final regex = RegExp('\\b${RegExp.escape(filler)}\\b');
      count += regex.allMatches(lower).length;
    }
    return count;
  }

  String _mapSpeechStatus(String rawStatus) {
    switch (rawStatus) {
      case 'listening':
        return 'Listening... keep speaking naturally.';
      case 'notListening':
        return 'Speech engine paused.';
      case 'done':
        return 'Speech recognition completed.';
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

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    final analysisResult = _analysisResult;
    final transcriptPreview = _transcript.trim().isEmpty
        ? 'Transcript will appear here while you speak.'
        : _transcript;
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
                decoration: const InputDecoration(
                  hintText: 'Example: Job interview self-introduction',
                  prefixIcon: Icon(Icons.topic_outlined),
                ),
              ),
              const SizedBox(height: 14),
              _StatusCard(
                statusText: _statusText,
                elapsedText: _formatDuration(_elapsed),
                isLive: _isSessionRunning,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactButtons = constraints.maxWidth < 390;
                  final startButton = FilledButton.icon(
                    onPressed: _isSessionRunning ? null : _startSession,
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
              const SizedBox(height: 16),
              Text(
                'Live Transcript',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF123B5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD1E4F7)),
                ),
                child: Text(
                  transcriptPreview,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF35536D),
                    height: 1.45,
                  ),
                ),
              ),
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
  });

  final String statusText;
  final String elapsedText;
  final bool isLive;

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
        ],
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
