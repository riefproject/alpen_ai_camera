import 'package:alpen_ai_camera/data/models/pose_template_model.dart';

abstract class PoseTemplateLocalDataSource {
  // TODO: Persist and retrieve pose templates from local storage without leaking storage format details upward.
  Future<List<PoseTemplateModel>> getAvailableTemplates();
  Future<PoseTemplateModel?> getTemplateById(String templateId);
  Future<void> saveTemplate(PoseTemplateModel template);
}
