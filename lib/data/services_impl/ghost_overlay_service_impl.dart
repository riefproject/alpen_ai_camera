import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/services/ghost_overlay_service.dart';

class GhostOverlayServiceImpl implements GhostOverlayService {
  const GhostOverlayServiceImpl();

  // TODO: Convert normalized reference landmarks into the concrete overlay coordinates used by the preview UI.
  @override
  List<PoseLandmark> project(
    PoseTemplate template, {
    required int previewWidth,
    required int previewHeight,
  }) {
    throw UnimplementedError(
      'GhostOverlayServiceImpl.project belum diimplementasikan.',
    );
  }
}
