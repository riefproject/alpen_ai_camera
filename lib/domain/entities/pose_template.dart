import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';

class PoseTemplate {
  const PoseTemplate({
    required this.templateId,
    required this.name,
    required this.landmarks,
    this.outlinePoints = const <PoseOutlinePoint>[],
    this.thumbnailPath,
    this.sourceImagePath,
  });

  // TODO: Store the reusable reference pose used for overlay guidance and similarity checks.
  final String templateId;
  final String name;
  final List<PoseLandmark> landmarks;
  final List<PoseOutlinePoint> outlinePoints;
  final String? thumbnailPath;
  final String? sourceImagePath;
}
