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
    final localMap = <String, PoseTemplateModel>{
      for (final template in localTemplates) template.id: template,
    };

    final templates = <PoseTemplate>[
      for (final def in DefaultPoseTemplates.all)
        if (localMap.containsKey(def.templateId))
          PoseTemplate(
            templateId: def.templateId,
            name: def.name,
            landmarks: def.landmarks,
            outlinePoints: def.outlinePoints,
            thumbnailPath: def.thumbnailPath,
            sourceImagePath: def.sourceImagePath,
            isFavorite: localMap[def.templateId]!.isFavorite,
          )
        else
          def,
      ...localTemplates
          .where((t) => !t.id.startsWith('default-'))
          .map((template) => template.toEntity()),
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

  @override
  Future<void> updateTemplate(PoseTemplate template) async {
    if (template.templateId.startsWith('default-')) {
      throw UnsupportedError('Cannot update default templates');
    }
    await _localDataSource.updateTemplate(
      PoseTemplateModel.fromEntity(template),
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    if (templateId.startsWith('default-')) {
      throw UnsupportedError('Cannot delete default templates');
    }
    await _localDataSource.deleteTemplate(templateId);
  }

  @override
  Future<void> toggleFavorite(String templateId) async {
    if (templateId.startsWith('default-')) {
      final existing = await _localDataSource.getTemplateById(templateId);
      if (existing == null) {
        final def = DefaultPoseTemplates.all
            .firstWhere((t) => t.templateId == templateId);
        final defModel = PoseTemplateModel.fromEntity(def);
        await _localDataSource.saveTemplate(
          PoseTemplateModel(
            id: defModel.id,
            name: defModel.name,
            landmarks: defModel.landmarks,
            outlinePoints: defModel.outlinePoints,
            thumbnailPath: defModel.thumbnailPath,
            sourceImagePath: defModel.sourceImagePath,
            isFavorite: true,
          ),
        );
      } else {
        await _localDataSource.toggleFavorite(templateId);
      }
    } else {
      await _localDataSource.toggleFavorite(templateId);
    }
  }
}
