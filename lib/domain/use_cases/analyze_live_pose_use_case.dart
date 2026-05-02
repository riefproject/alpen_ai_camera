import 'dart:typed_data';

import 'package:alpen_ai_camera/core/math/pose_score_calculator.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/repositories/pose_repository.dart';
import 'package:alpen_ai_camera/domain/services/pose_detector_service.dart';

class AnalyzeLivePoseUseCase {
  AnalyzeLivePoseUseCase({
    required PoseRepository poseRepository,
    required PoseDetectorService poseDetectorService,
    required PoseScoreCalculator poseScoreCalculator,
  }) : _poseRepository = poseRepository,
       _poseDetectorService = poseDetectorService,
       _poseScoreCalculator = poseScoreCalculator;

  // TODO: Orchestrate live-frame detection, template lookup, and final pose matching in one application flow.
  final PoseRepository _poseRepository;
  final PoseDetectorService _poseDetectorService;
  final PoseScoreCalculator _poseScoreCalculator;

  PoseRepository get poseRepository => _poseRepository;
  PoseDetectorService get poseDetectorService => _poseDetectorService;
  PoseScoreCalculator get poseScoreCalculator => _poseScoreCalculator;

  Future<PoseMatchResult> call({
    required String templateId,
    required Uint8List frameBytes,
    required int width,
    required int height,
  }) {
    throw UnimplementedError(
      'AnalyzeLivePoseUseCase.call belum diimplementasikan.',
    );
  }
}
