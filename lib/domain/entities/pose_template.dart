import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';

class PoseTemplate {
  const PoseTemplate({
    required this.templateId,
    required this.name,
    required this.landmarks,
    this.sourceImagePath,
  });

  // TODO: Store the reusable reference pose used for overlay guidance and similarity checks.
  final String templateId;
  final String name;
  final List<PoseLandmark> landmarks;
  final String? sourceImagePath;
}
