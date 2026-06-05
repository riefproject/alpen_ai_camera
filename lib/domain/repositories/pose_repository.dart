import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

abstract class PoseRepository {
  // TODO: Coordinate pose template persistence and retrieval without exposing storage details to the domain layer.
  Future<List<PoseTemplate>> getAvailableTemplates();
  Future<PoseTemplate?> getTemplateById(String templateId);
  Future<void> saveTemplate(PoseTemplate template);
  Future<void> updateTemplate(PoseTemplate template);
  Future<void> deleteTemplate(String templateId);
  Future<void> toggleFavorite(String templateId);
}
