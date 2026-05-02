import 'package:alpen_ai_camera/data/datasources/local/pose_template_local_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/repositories/pose_repository.dart';

class PoseRepositoryImpl implements PoseRepository {
  const PoseRepositoryImpl({
    required PoseTemplateLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  // TODO: Assemble pose template reads and writes from the chosen local data source implementation.
  final PoseTemplateLocalDataSource _localDataSource;

  PoseTemplateLocalDataSource get localDataSource => _localDataSource;

  @override
  Future<List<PoseTemplate>> getAvailableTemplates() {
    throw UnimplementedError(
      'PoseRepositoryImpl.getAvailableTemplates belum diimplementasikan.',
    );
  }

  @override
  Future<PoseTemplate?> getTemplateById(String templateId) {
    throw UnimplementedError(
      'PoseRepositoryImpl.getTemplateById belum diimplementasikan.',
    );
  }

  @override
  Future<void> saveTemplate(PoseTemplate template) {
    throw UnimplementedError(
      'PoseRepositoryImpl.saveTemplate belum diimplementasikan.',
    );
  }
}
