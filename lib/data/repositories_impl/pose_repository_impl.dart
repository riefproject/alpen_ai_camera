import 'package:alpen_ai_camera/data/datasources/local/pose_template_local_datasource.dart';
import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:alpen_ai_camera/core/constants/default_pose_templates.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/repositories/pose_repository.dart';

class PoseRepositoryImpl implements PoseRepository {
  const PoseRepositoryImpl({
    required PoseTemplateLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final PoseTemplateLocalDataSource _localDataSource;

  PoseTemplateLocalDataSource get localDataSource => _localDataSource;

  @override
  Future<List<PoseTemplate>> getAvailableTemplates() async {
    final localTemplates = await _localDataSource.getAvailableTemplates();
    final templates = <PoseTemplate>[
      ...DefaultPoseTemplates.all,
      ...localTemplates.map((template) => template.toEntity()),
    ];
    return templates;
  }

  @override
  Future<PoseTemplate?> getTemplateById(String templateId) async {
    for (final template in DefaultPoseTemplates.all) {
      if (template.templateId == templateId) {
        return template;
      }
    }

    return (await _localDataSource.getTemplateById(templateId))?.toEntity();
  }

  @override
  Future<void> saveTemplate(PoseTemplate template) {
    return _localDataSource.saveTemplate(PoseTemplateModel.fromEntity(template));
  }
}
