import 'package:alpen_ai_camera/domain/use_cases/analyze_live_pose_use_case.dart';
import 'package:alpen_ai_camera/domain/use_cases/build_pose_template_from_upload_use_case.dart';
import 'package:flutter/foundation.dart';

class PoseWorkflowController extends ChangeNotifier {
  PoseWorkflowController({
    required AnalyzeLivePoseUseCase analyzeLivePoseUseCase,
    required BuildPoseTemplateFromUploadUseCase
    buildPoseTemplateFromUploadUseCase,
  }) : _analyzeLivePoseUseCase = analyzeLivePoseUseCase,
       _buildPoseTemplateFromUploadUseCase = buildPoseTemplateFromUploadUseCase;

  // TODO: Coordinate the two primary app modes so UI state stays slim while pose workflows remain testable.
  final AnalyzeLivePoseUseCase _analyzeLivePoseUseCase;
  final BuildPoseTemplateFromUploadUseCase _buildPoseTemplateFromUploadUseCase;

  AnalyzeLivePoseUseCase get analyzeLivePoseUseCase => _analyzeLivePoseUseCase;
  BuildPoseTemplateFromUploadUseCase get buildPoseTemplateFromUploadUseCase =>
      _buildPoseTemplateFromUploadUseCase;
}
