import 'dart:io';

import 'package:record/record.dart';

class RecordingService {
  RecordingService() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  bool _isRecording = false;

  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (_isRecording) {
      return;
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: _buildRecordingPath(),
    );
    _isRecording = true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  String _buildRecordingPath() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempDir = Directory.systemTemp.path;
    return '$tempDir/speech_session_$timestamp.m4a';
  }
}
