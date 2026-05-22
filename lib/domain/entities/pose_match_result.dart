import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';

class PoseMatchResult {
  const PoseMatchResult({
    required this.isMatched,
    required this.score,
    required this.feedbackMessage,
    this.lowConfidenceLandmarks = const <String>[],
    this.misalignedLandmarks = const <String>[],
    this.candidateLandmarks = const <PoseLandmark>[],
    this.landmarkScores = const <String, double>{},
    this.segmentScores = const <String, double>{},
  });

  final bool isMatched;
  final double score;
  final String feedbackMessage;
  final List<String> lowConfidenceLandmarks;
  final List<String> misalignedLandmarks;
  final List<PoseLandmark> candidateLandmarks;
  final Map<String, double> landmarkScores;
  final Map<String, double> segmentScores;
}
