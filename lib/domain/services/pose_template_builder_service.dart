import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

abstract class PoseTemplateBuilderService {
  // TODO: Build clean, reusable pose templates from user-provided reference images.
  Future<PoseTemplate> createFromImage({
    required String imagePath,
    required String templateName,
  });
}
