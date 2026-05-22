import 'dart:math' as math;

import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';
import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

class PoseScoreCalculator {
  const PoseScoreCalculator({
    this.matchThreshold = 0.86,
    this.minimumVisibility = 0.35,
  });

  final double matchThreshold;
  final double minimumVisibility;

  PoseMatchResult calculate({
    required PoseTemplate referencePose,
    required PoseFrame candidatePose,
  }) {
    final normalResult = _calculateAgainst(
      referencePose: referencePose,
      candidateLandmarks: candidatePose.landmarks,
    );
    final mirroredLandmarks = _mirrorHorizontally(candidatePose.landmarks);
    final mirroredResult = _calculateAgainst(
      referencePose: referencePose,
      candidateLandmarks: mirroredLandmarks,
    );

    return mirroredResult.score > normalResult.score
        ? mirroredResult
        : normalResult;
  }

  PoseMatchResult _calculateAgainst({
    required PoseTemplate referencePose,
    required List<PoseLandmark> candidateLandmarks,
  }) {
    final reference = _normalize(referencePose.landmarks);
    final candidate = _normalize(candidateLandmarks);
    if (reference.isEmpty || candidate.isEmpty) {
      return PoseMatchResult(
        isMatched: false,
        score: 0,
        feedbackMessage: 'Pose belum terdeteksi jelas',
        candidateLandmarks: candidateLandmarks,
      );
    }

    double totalScore = 0;
    var matchedLandmarkCount = 0;
    double segmentTotalScore = 0;
    var matchedSegmentCount = 0;
    final misaligned = <String>[];
    final lowConfidence = <String>[];
    final landmarkScores = <String, double>{};
    final segmentScores = <String, double>{};

    for (final entry in reference.entries) {
      final candidateLandmark = candidate[entry.key];
      if (candidateLandmark == null) {
        lowConfidence.add(entry.key);
        continue;
      }

      if ((candidateLandmark.visibility ?? 1) < minimumVisibility) {
        lowConfidence.add(entry.key);
        continue;
      }

      final distance = _distance(entry.value, candidateLandmark);
      final landmarkScore = (1 - (distance / 0.85)).clamp(0.0, 1.0);
      landmarkScores[entry.key] = landmarkScore;
      totalScore += landmarkScore;
      matchedLandmarkCount++;

      if (landmarkScore < 0.68) {
        misaligned.add(entry.key);
      }
    }

    for (final segment in _segments.entries) {
      final score = _segmentScore(
        segment.value,
        reference: reference,
        candidate: candidate,
        landmarkScores: landmarkScores,
      );
      if (score == null) {
        continue;
      }

      segmentScores[segment.key] = score;
      segmentTotalScore += score;
      matchedSegmentCount++;
      if (score < 0.68) {
        misaligned.addAll(segment.value);
      }
    }

    final uniqueMisaligned = misaligned.toSet().toList();

    if (matchedLandmarkCount < 8) {
      return PoseMatchResult(
        isMatched: false,
        score: 0,
        feedbackMessage: 'Masuk ke frame dan ikuti outline',
        lowConfidenceLandmarks: lowConfidence,
        misalignedLandmarks: uniqueMisaligned,
        candidateLandmarks: candidateLandmarks,
        landmarkScores: landmarkScores,
        segmentScores: segmentScores,
      );
    }

    final landmarkAverage = totalScore / matchedLandmarkCount;
    final segmentAverage = matchedSegmentCount == 0
        ? landmarkAverage
        : segmentTotalScore / matchedSegmentCount;
    final score = ((landmarkAverage * 0.62) + (segmentAverage * 0.38)).clamp(
      0.0,
      1.0,
    );
    final hasBadSegment = segmentScores.values.any((score) => score < 0.68);
    return PoseMatchResult(
      isMatched: score >= matchThreshold && !hasBadSegment,
      score: score,
      feedbackMessage: _feedbackFor(score, uniqueMisaligned, lowConfidence),
      lowConfidenceLandmarks: lowConfidence,
      misalignedLandmarks: uniqueMisaligned,
      candidateLandmarks: candidateLandmarks,
      landmarkScores: landmarkScores,
      segmentScores: segmentScores,
    );
  }

  List<PoseLandmark> _mirrorHorizontally(List<PoseLandmark> landmarks) {
    return landmarks
        .map(
          (landmark) => PoseLandmark(
            name: landmark.name,
            x: 1 - landmark.x,
            y: landmark.y,
            z: landmark.z,
            visibility: landmark.visibility,
          ),
        )
        .toList();
  }

  Map<String, PoseLandmark> _normalize(List<PoseLandmark> landmarks) {
    final visible = <String, PoseLandmark>{
      for (final landmark in landmarks)
        if ((landmark.visibility ?? 1) >= minimumVisibility)
          landmark.name: landmark,
    };

    final leftShoulder = visible['leftShoulder'];
    final rightShoulder = visible['rightShoulder'];
    final leftHip = visible['leftHip'];
    final rightHip = visible['rightHip'];
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return visible;
    }

    final centerX =
        (leftShoulder.x + rightShoulder.x + leftHip.x + rightHip.x) / 4;
    final centerY =
        (leftShoulder.y + rightShoulder.y + leftHip.y + rightHip.y) / 4;
    final shoulderWidth = _distance(leftShoulder, rightShoulder);
    final torsoHeight = _distance(
      PoseLandmark(
        name: 'shoulderCenter',
        x: (leftShoulder.x + rightShoulder.x) / 2,
        y: (leftShoulder.y + rightShoulder.y) / 2,
      ),
      PoseLandmark(
        name: 'hipCenter',
        x: (leftHip.x + rightHip.x) / 2,
        y: (leftHip.y + rightHip.y) / 2,
      ),
    );
    final scale = math.max(shoulderWidth, torsoHeight).clamp(0.001, 10.0);

    return <String, PoseLandmark>{
      for (final landmark in visible.entries)
        landmark.key: PoseLandmark(
          name: landmark.value.name,
          x: (landmark.value.x - centerX) / scale,
          y: (landmark.value.y - centerY) / scale,
          z: landmark.value.z,
          visibility: landmark.value.visibility,
        ),
    };
  }

  double? _segmentScore(
    List<String> names, {
    required Map<String, PoseLandmark> reference,
    required Map<String, PoseLandmark> candidate,
    required Map<String, double> landmarkScores,
  }) {
    final referencePoints = names.map((name) => reference[name]).toList();
    final candidatePoints = names.map((name) => candidate[name]).toList();
    if (referencePoints.any((point) => point == null) ||
        candidatePoints.any((point) => point == null)) {
      return null;
    }

    final pointScore =
        names.map((name) => landmarkScores[name] ?? 0).reduce((a, b) => a + b) /
        names.length;
    final directionScore = _directionScore(
      referencePoints[0]!,
      referencePoints.last!,
      candidatePoints[0]!,
      candidatePoints.last!,
    );
    final angleScore = names.length < 3
        ? directionScore
        : _jointAngleScore(
            referencePoints[0]!,
            referencePoints[1]!,
            referencePoints[2]!,
            candidatePoints[0]!,
            candidatePoints[1]!,
            candidatePoints[2]!,
          );

    return ((pointScore * 0.52) + (directionScore * 0.24) + (angleScore * 0.24))
        .clamp(0.0, 1.0);
  }

  double _directionScore(
    PoseLandmark referenceStart,
    PoseLandmark referenceEnd,
    PoseLandmark candidateStart,
    PoseLandmark candidateEnd,
  ) {
    final referenceAngle = math.atan2(
      referenceEnd.y - referenceStart.y,
      referenceEnd.x - referenceStart.x,
    );
    final candidateAngle = math.atan2(
      candidateEnd.y - candidateStart.y,
      candidateEnd.x - candidateStart.x,
    );
    final difference = _angleDifference(referenceAngle, candidateAngle);
    return (1 - (difference / math.pi)).clamp(0.0, 1.0);
  }

  double _jointAngleScore(
    PoseLandmark referenceA,
    PoseLandmark referenceB,
    PoseLandmark referenceC,
    PoseLandmark candidateA,
    PoseLandmark candidateB,
    PoseLandmark candidateC,
  ) {
    final referenceAngle = _jointAngle(referenceA, referenceB, referenceC);
    final candidateAngle = _jointAngle(candidateA, candidateB, candidateC);
    final difference = _angleDifference(referenceAngle, candidateAngle);
    return (1 - (difference / math.pi)).clamp(0.0, 1.0);
  }

  double _jointAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = math.atan2(a.y - b.y, a.x - b.x);
    final cb = math.atan2(c.y - b.y, c.x - b.x);
    return _angleDifference(ab, cb);
  }

  double _angleDifference(double a, double b) {
    var difference = (a - b).abs() % (math.pi * 2);
    if (difference > math.pi) {
      difference = (math.pi * 2) - difference;
    }
    return difference;
  }

  double _distance(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  String _feedbackFor(
    double score,
    List<String> misaligned,
    List<String> lowConfidence,
  ) {
    if (score >= matchThreshold && misaligned.isEmpty) {
      return 'Pose cocok';
    }
    if (lowConfidence.length > 4) {
      return 'Pastikan tubuh terlihat jelas';
    }
    if (misaligned.isNotEmpty) {
      return 'Sesuaikan ${_readableLandmark(misaligned.first)}';
    }
    if (score < 0.55) {
      return 'Ikuti outline pose';
    }
    return 'Sedikit lagi';
  }

  String _readableLandmark(String landmark) {
    const labels = <String, String>{
      'leftShoulder': 'bahu kiri',
      'rightShoulder': 'bahu kanan',
      'leftElbow': 'siku kiri',
      'rightElbow': 'siku kanan',
      'leftWrist': 'tangan kiri',
      'rightWrist': 'tangan kanan',
      'leftHip': 'pinggul kiri',
      'rightHip': 'pinggul kanan',
      'leftKnee': 'lutut kiri',
      'rightKnee': 'lutut kanan',
      'leftAnkle': 'kaki kiri',
      'rightAnkle': 'kaki kanan',
    };
    return labels[landmark] ?? landmark;
  }
}

const Map<String, List<String>> _segments = <String, List<String>>{
  'torso': <String>['leftShoulder', 'rightShoulder', 'rightHip', 'leftHip'],
  'leftUpperArm': <String>['leftShoulder', 'leftElbow'],
  'leftLowerArm': <String>['leftElbow', 'leftWrist'],
  'rightUpperArm': <String>['rightShoulder', 'rightElbow'],
  'rightLowerArm': <String>['rightElbow', 'rightWrist'],
  'leftLeg': <String>['leftHip', 'leftKnee', 'leftAnkle'],
  'rightLeg': <String>['rightHip', 'rightKnee', 'rightAnkle'],
  'leftFoot': <String>['leftAnkle', 'leftFootIndex'],
  'rightFoot': <String>['rightAnkle', 'rightFootIndex'],
};
