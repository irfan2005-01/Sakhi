import 'dart:typed_data';

class RecordedAudio {
  final Uint8List bytes;
  final String mimeType;
  final String filename;

  const RecordedAudio({
    required this.bytes,
    required this.mimeType,
    required this.filename,
  });
}
