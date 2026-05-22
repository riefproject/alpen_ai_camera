import 'dart:typed_data';

class CameraFramePayload {
  const CameraFramePayload({
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.formatRaw,
    required this.bytesPerRow,
    required this.planeCount,
    this.diagnosticLabel,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int rotationDegrees;
  final int formatRaw;
  final int bytesPerRow;
  final int planeCount;
  final String? diagnosticLabel;
}

abstract class CameraFrameDataSource {
  Future<void> initialize();
  Stream<CameraFramePayload> startImageStream();
  Future<void> dispose();
}
