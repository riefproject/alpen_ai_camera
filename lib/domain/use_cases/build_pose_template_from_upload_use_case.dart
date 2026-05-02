import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/repositories/pose_repository.dart';
import 'package:alpen_ai_camera/domain/services/pose_template_builder_service.dart';

class BuildPoseTemplateFromUploadUseCase {
  BuildPoseTemplateFromUploadUseCase({
    required PoseRepository poseRepository,
    required PoseTemplateBuilderService poseTemplateBuilderService,
  }) : _poseRepository = poseRepository,
       _poseTemplateBuilderService = poseTemplateBuilderService;

  // TODO: Turn an uploaded reference image into a saved pose template ready for the live comparison flow.
  final PoseRepository _poseRepository;
  final PoseTemplateBuilderService _poseTemplateBuilderService;

  PoseRepository get poseRepository => _poseRepository;
  PoseTemplateBuilderService get poseTemplateBuilderService =>
      _poseTemplateBuilderService;

  Future<PoseTemplate> call({
    required String imagePath,
    required String templateName,
  }) {
    throw UnimplementedError(
      'BuildPoseTemplateFromUploadUseCase.call belum diimplementasikan.',
    );
  }
}
