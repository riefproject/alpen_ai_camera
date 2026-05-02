import 'package:alpen_ai_camera/data/datasources/image_processing/image_preprocessor_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/services/pose_detector_service.dart';
import 'package:alpen_ai_camera/domain/services/pose_template_builder_service.dart';

class PoseTemplateBuilderServiceImpl implements PoseTemplateBuilderService {
  const PoseTemplateBuilderServiceImpl({
    required ImagePreprocessorDataSource imagePreprocessorDataSource,
    required PoseDetectorService poseDetectorService,
  }) : _imagePreprocessorDataSource = imagePreprocessorDataSource,
       _poseDetectorService = poseDetectorService;

  // TODO: Chain preprocessing and pose detection into a clean template-building pipeline for uploaded images.
  final ImagePreprocessorDataSource _imagePreprocessorDataSource;
  final PoseDetectorService _poseDetectorService;

  ImagePreprocessorDataSource get imagePreprocessorDataSource =>
      _imagePreprocessorDataSource;
  PoseDetectorService get poseDetectorService => _poseDetectorService;

  @override
  Future<PoseTemplate> createFromImage({
    required String imagePath,
    required String templateName,
  }) {
    throw UnimplementedError(
      'PoseTemplateBuilderServiceImpl.createFromImage belum diimplementasikan.',
    );
  }
}
