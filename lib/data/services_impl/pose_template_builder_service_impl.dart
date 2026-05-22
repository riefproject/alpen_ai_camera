import 'package:alpen_ai_camera/data/datasources/image_processing/image_preprocessor_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/services/pose_outline_builder_service.dart';
import 'package:alpen_ai_camera/domain/services/pose_detector_service.dart';
import 'package:alpen_ai_camera/domain/services/pose_template_builder_service.dart';

class PoseTemplateBuilderServiceImpl implements PoseTemplateBuilderService {
  const PoseTemplateBuilderServiceImpl({
    required ImagePreprocessorDataSource imagePreprocessorDataSource,
    required PoseDetectorService poseDetectorService,
    required PoseOutlineBuilderService poseOutlineBuilderService,
  }) : _imagePreprocessorDataSource = imagePreprocessorDataSource,
       _poseDetectorService = poseDetectorService,
       _poseOutlineBuilderService = poseOutlineBuilderService;

  // TODO: Chain preprocessing and pose detection into a clean template-building pipeline for uploaded images.
  final ImagePreprocessorDataSource _imagePreprocessorDataSource;
  final PoseDetectorService _poseDetectorService;
  final PoseOutlineBuilderService _poseOutlineBuilderService;

  ImagePreprocessorDataSource get imagePreprocessorDataSource =>
      _imagePreprocessorDataSource;
  PoseDetectorService get poseDetectorService => _poseDetectorService;

  @override
  Future<PoseTemplate> createFromImage({
    required String imagePath,
    required String templateName,
  }) async {
    await _imagePreprocessorDataSource.preprocessStillImage(imagePath);
    final frame = await _poseDetectorService.detectFromImage(imagePath);
    _validateTemplateLandmarks(frame.landmarks);
    final outlinePoints = await _poseOutlineBuilderService.buildFromImage(
      imagePath,
    );

    return PoseTemplate(
      templateId: 'upload-${DateTime.now().microsecondsSinceEpoch}',
      name: templateName.trim().isEmpty ? 'Pose Upload' : templateName.trim(),
      landmarks: frame.landmarks,
      outlinePoints: outlinePoints,
      sourceImagePath: imagePath,
    );
  }

  void _validateTemplateLandmarks(List<PoseLandmark> landmarks) {
    final byName = <String, PoseLandmark>{
      for (final landmark in landmarks) landmark.name: landmark,
    };
    const requiredLandmarks = <String>[
      'nose',
      'leftShoulder',
      'rightShoulder',
      'leftElbow',
      'rightElbow',
      'leftHip',
      'rightHip',
      'leftKnee',
      'rightKnee',
      'leftAnkle',
      'rightAnkle',
    ];

    final hasRequiredLandmarks = requiredLandmarks.every((name) {
      final landmark = byName[name];
      return landmark != null && (landmark.visibility ?? 1) >= 0.62;
    });
    if (!hasRequiredLandmarks) {
      throw StateError(
        'Tubuh tidak terlihat penuh atau landmark inti kurang jelas.',
      );
    }

    final visibleLandmarks = landmarks
        .where((landmark) => (landmark.visibility ?? 1) >= 0.5)
        .length;
    if (visibleLandmarks < 14) {
      throw StateError('Pose tidak cukup jelas untuk dijadikan template.');
    }
  }
}
