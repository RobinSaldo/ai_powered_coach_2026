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

  Future<bool> startListening({required SpeechResultHandler onResult}) async {
    await _speech.listen(
      onResult: onResult,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 5),
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
}
