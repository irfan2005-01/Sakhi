import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'browser_voice_models.dart';

const _mediaRecorderDataAvailable = html.EventStreamProvider<html.BlobEvent>('dataavailable');
const _mediaRecorderStop = html.EventStreamProvider<html.Event>('stop');

class BrowserVoiceRecorder {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  Completer<RecordedAudio>? _recordingComplete;
  StreamSubscription<html.BlobEvent>? _dataSubscription;
  StreamSubscription<html.Event>? _stopSubscription;
  String _mimeType = 'audio/webm';

  String get _filenameExtension {
    if (_mimeType.contains('ogg')) return 'ogg';
    if (_mimeType.contains('mp4')) return 'm4a';
    if (_mimeType.contains('wav')) return 'wav';
    return 'webm';
  }

  bool get isRecording => _recorder?.state == 'recording';

  Future<void> start() async {
    _stream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
    _recorder = html.MediaRecorder(_stream!);
    final recorderMimeType = _recorder!.mimeType;
    _mimeType = recorderMimeType?.trim().isNotEmpty == true
        ? recorderMimeType!.trim()
        : 'audio/webm';
    _chunks.clear();
    _recordingComplete = Completer<RecordedAudio>();
    _dataSubscription = _mediaRecorderDataAvailable.forTarget(_recorder).listen((event) {
      if (event.data != null && event.data!.size > 0) _chunks.add(event.data!);
    });
    _stopSubscription = _mediaRecorderStop.forTarget(_recorder).listen((_) {
      final reader = html.FileReader();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is Uint8List) {
          _recordingComplete?.complete(RecordedAudio(
            bytes: result,
            mimeType: _mimeType,
            filename: 'recording.$_filenameExtension',
          ));
        } else if (result is ByteBuffer) {
          _recordingComplete?.complete(RecordedAudio(
            bytes: Uint8List.view(result),
            mimeType: _mimeType,
            filename: 'recording.$_filenameExtension',
          ));
        } else {
          _recordingComplete?.completeError(StateError('The browser could not read the audio recording.'));
        }
      });
      reader.readAsArrayBuffer(html.Blob(_chunks));
    });
    _recorder!.start();
  }

  Future<RecordedAudio> stop() async {
    final recorder = _recorder;
    final completion = _recordingComplete;
    if (recorder == null || completion == null) {
      throw StateError('No microphone recording is active.');
    }
    if (recorder.state == 'recording') recorder.stop();
    try {
      return await completion.future.timeout(const Duration(seconds: 10));
    } finally {
      _stopTracks();
      await _dataSubscription?.cancel();
      await _stopSubscription?.cancel();
      _recorder = null;
      _recordingComplete = null;
    }
  }

  void _stopTracks() {
    for (final track in _stream?.getTracks() ?? <html.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
  }

  void dispose() {
    if (_recorder?.state == 'recording') _recorder!.stop();
    _stopTracks();
    _dataSubscription?.cancel();
    _stopSubscription?.cancel();
  }
}

class BrowserVoicePlayer {
  html.AudioElement? _audio;
  Completer<void>? _playbackComplete;

  Future<void> playBase64Wav(String audioBase64) async {
    dispose();
    final audio = html.AudioElement('data:audio/wav;base64,$audioBase64');
    final completion = Completer<void>();
    _audio = audio;
    _playbackComplete = completion;
    audio.onEnded.first.then((_) {
      if (!completion.isCompleted) completion.complete();
    });
    audio.onError.first.then((_) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('The browser could not play the spoken response.'));
      }
    });
    await audio.play();
    await completion.future;
  }

  void dispose() {
    _audio?.pause();
    _audio?.remove();
    _audio = null;
    if (_playbackComplete != null && !_playbackComplete!.isCompleted) {
      _playbackComplete!.complete();
    }
    _playbackComplete = null;
  }
}
