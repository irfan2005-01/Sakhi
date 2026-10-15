import 'browser_voice_models.dart';

class BrowserVoiceRecorder {
  bool get isRecording => false;

  Future<void> start() async {
    throw UnsupportedError('Microphone recording is available in Flutter Web.');
  }

  Future<RecordedAudio> stop() async {
    throw UnsupportedError('Microphone recording is available in Flutter Web.');
  }

  void dispose() {}
}

class BrowserVoicePlayer {
  Future<void> playBase64Wav(String audioBase64) async {
    throw UnsupportedError('Audio playback is available in Flutter Web.');
  }

  void dispose() {}
}
