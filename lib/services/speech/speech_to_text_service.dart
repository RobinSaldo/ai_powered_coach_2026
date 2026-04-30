import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef SpeechStatusHandler = void Function(String status);
typedef SpeechErrorHandler = void Function(SpeechRecognitionError error);
typedef SpeechResultHandler = void Function(SpeechRecognitionResult result);

class SpeechToTextService {
  SpeechToTextService() : _speech = SpeechToText();

  final SpeechToText _speech;

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    SpeechStatusHandler? onStatus,
    SpeechErrorHandler? onError,
  }) {
    return _speech.initialize(onStatus: onStatus, onError: onError);
  }

  Future<bool> startListening({
    required SpeechResultHandler onResult,
    Duration listenFor = const Duration(minutes: 5),
    Duration pauseFor = const Duration(seconds: 3),
    String? localeId,
  }) async {
    await _speech.listen(
      onResult: onResult,
      listenFor: listenFor,
      pauseFor: pauseFor,
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
    return _speech.isListening;
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
  }

  Future<String?> resolveBestLocale({
    required List<String> preferredLocaleIds,
  }) async {
    final availableLocales = await _speech.locales();
    if (availableLocales.isEmpty) {
      return null;
    }

    for (final preferred in preferredLocaleIds) {
      for (final locale in availableLocales) {
        if (locale.localeId.toLowerCase() == preferred.toLowerCase()) {
          return locale.localeId;
        }
      }
    }

    return availableLocales.first.localeId;
  }
}
