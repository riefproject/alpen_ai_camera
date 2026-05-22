import 'dart:typed_data';

import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';

abstract class PoseDetectorService {
  // TODO: Define pose landmark extraction for both uploaded images and real-time camera frames.
  Future<PoseFrame> detectFromImage(String imagePath);
  Future<PoseFrame> detectFromBytes(
    Uint8List bytes, {
    required int width,
    required int height,
    int rotationDegrees = 0,
    int formatRaw = 17,
    int bytesPerRow = 0,
  });
}
