import 'dart:typed_data';

class CameraFramePayload {
  const CameraFramePayload({
    required this.bytes,
    required this.width,
    required this.height,
  });

  // TODO: Represent raw camera image-stream frames before they enter preprocessing or ML inference.
  final Uint8List bytes;
  final int width;
  final int height;
}

abstract class CameraFrameDataSource {
  // TODO: Own low-level camera image-stream access and lifecycle at the data layer boundary.
  Future<void> initialize();
  Stream<CameraFramePayload> startImageStream();
  Future<void> dispose();
}
