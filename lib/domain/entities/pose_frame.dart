import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';

class PoseFrame {
  const PoseFrame({
    required this.frameId,
    required this.landmarks,
    required this.width,
    required this.height,
    required this.capturedAt,
  });

  // TODO: Carry one detected pose snapshot from either live camera frames or uploaded images.
  final String frameId;
  final List<PoseLandmark> landmarks;
  final int width;
  final int height;
  final DateTime capturedAt;
}
