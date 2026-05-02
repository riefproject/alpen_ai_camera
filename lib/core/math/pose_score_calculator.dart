import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

class PoseScoreCalculator {
  const PoseScoreCalculator();

  // TODO: Calculate normalized similarity metrics between detected user pose and the reference template.
  PoseMatchResult calculate({
    required PoseTemplate referencePose,
    required PoseFrame candidatePose,
  }) {
    throw UnimplementedError(
      'PoseScoreCalculator.calculate belum diimplementasikan.',
    );
  }
}
