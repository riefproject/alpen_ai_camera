import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

abstract class GhostOverlayService {
  // TODO: Map a reference pose into preview-space points that can be rendered as an alignment overlay.
  List<PoseLandmark> project(
    PoseTemplate template, {
    required int previewWidth,
    required int previewHeight,
  });
}
