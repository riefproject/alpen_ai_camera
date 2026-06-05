import 'dart:math' as math;

import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';
import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

class PoseScoreCalculator {
  const PoseScoreCalculator({
    this.matchThreshold = 0.88,
    this.minimumVisibility = 0.50,
    this.positionWeight = 0.55,
  });

  final double matchThreshold;
  final double minimumVisibility;
  final double positionWeight;

  PoseMatchResult calculate({
    required PoseTemplate referencePose,
    required PoseFrame candidatePose,
  }) {
    final positionScore = _computePositionScore(
      referenceLandmarks: referencePose.landmarks,
      candidateLandmarks: candidatePose.landmarks,
    );

    final normalResult = _calculateAgainst(
      referencePose: referencePose,
      candidateLandmarks: candidatePose.landmarks,
      positionScore: positionScore,
    );

    final mirroredLandmarks = _mirrorHorizontally(candidatePose.landmarks);
    final mirroredResult = _calculateAgainst(
      referencePose: referencePose,
      candidateLandmarks: mirroredLandmarks,
      positionScore: positionScore,
    );

    final best = mirroredResult.score > normalResult.score
        ? mirroredResult
        : normalResult;

    if (best.score < matchThreshold && normalResult.score >= matchThreshold) {
      return normalResult;
    }

    return best;
  }

  PoseMatchResult _calculateAgainst({
    required PoseTemplate referencePose,
    required List<PoseLandmark> candidateLandmarks,
    double positionScore = 1.0,
  }) {
    final visibilityGate = _visibilityGate(candidateLandmarks);
    final reference = _normalize(referencePose.landmarks);
    final candidate = _normalize(candidateLandmarks);
    if (reference.isEmpty ||
        candidate.isEmpty ||
        visibilityGate.scoreCap == 0) {
      return PoseMatchResult(
        isMatched: false,
        score: 0,
        feedbackMessage:
            visibilityGate.feedbackMessage ?? 'Pose belum terdeteksi jelas',
        lowConfidenceLandmarks: visibilityGate.missingLandmarks,
        candidateLandmarks: candidateLandmarks,
      );
    }

    double totalScore = 0;
    double matchedLandmarkWeight = 0;
    var matchedLandmarkCount = 0;
    double segmentTotalScore = 0;
    double matchedSegmentWeight = 0;
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
      final distanceRatio = (distance / _distanceTolerance(entry.key)).clamp(0.0, 1.0);
      final landmarkScore = 1 - distanceRatio;
      final weight = _landmarkWeight(entry.key);
      landmarkScores[entry.key] = landmarkScore;
      totalScore += landmarkScore * weight;
      matchedLandmarkWeight += weight;
      matchedLandmarkCount++;

      if (landmarkScore < _misalignmentThreshold(entry.key)) {
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

      final weight = _segmentWeight(segment.key);
      segmentScores[segment.key] = score;
      segmentTotalScore += score * weight;
      matchedSegmentWeight += weight;
      if (score < _segmentMisalignmentThreshold(segment.key)) {
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

    final landmarkAverage = totalScore / matchedLandmarkWeight;
    final segmentAverage = matchedSegmentWeight == 0
        ? landmarkAverage
        : segmentTotalScore / matchedSegmentWeight;
    final poseScore = ((landmarkAverage * 0.55) + (segmentAverage * 0.45)).clamp(
      0.0,
      1.0,
    );
    final gatedScore = math.min(poseScore, visibilityGate.scoreCap);
    final positionedScore = gatedScore * ((1 - positionWeight) + (positionWeight * positionScore));
    final hasBadSegment = segmentScores.entries.any(
      (entry) => entry.value < _blockingSegmentThreshold(entry.key),
    );
    return PoseMatchResult(
      isMatched: positionedScore >= matchThreshold && !hasBadSegment,
      score: positionedScore,
      feedbackMessage:
          visibilityGate.feedbackMessage ??
          _feedbackFor(positionedScore, uniqueMisaligned, lowConfidence),
      lowConfidenceLandmarks: <String>{
        ...lowConfidence,
        ...visibilityGate.missingLandmarks,
      }.toList(),
      misalignedLandmarks: uniqueMisaligned,
      candidateLandmarks: candidateLandmarks,
      landmarkScores: landmarkScores,
      segmentScores: segmentScores,
    );
  }

  _PoseVisibilityGate _visibilityGate(List<PoseLandmark> landmarks) {
    final visible = <String, PoseLandmark>{
      for (final landmark in landmarks)
        if (!_ignoredLandmarks.contains(landmark.name) &&
            (landmark.visibility ?? 1) >= minimumVisibility)
          landmark.name: landmark,
    };

    final missingCore = _coreLandmarks
        .where((name) => !visible.containsKey(name))
        .toList();
    if (missingCore.isNotEmpty) {
      return _PoseVisibilityGate(
        scoreCap: 0,
        feedbackMessage: 'Arahkan badan penuh ke kamera',
        missingLandmarks: missingCore,
      );
    }

    final visibleRequired = _requiredBodyLandmarks
        .where((name) => visible.containsKey(name))
        .length;
    final missingRequired = _requiredBodyLandmarks
        .where((name) => !visible.containsKey(name))
        .toList();
    final visibleLower = _requiredLowerBodyLandmarks
        .where((name) => visible.containsKey(name))
        .length;
    final visibleArms = _requiredArmLandmarks
        .where((name) => visible.containsKey(name))
        .length;

    if (visibleRequired < 8) {
      return _PoseVisibilityGate(
        scoreCap: 0,
        feedbackMessage: 'Masuk ke frame dan ikuti outline',
        missingLandmarks: missingRequired,
      );
    }
    if (visibleLower < 2) {
      return _PoseVisibilityGate(
        scoreCap: 0.34,
        feedbackMessage: 'Pastikan tubuh terlihat penuh',
        missingLandmarks: missingRequired,
      );
    }
    if (visibleLower < 4) {
      return _PoseVisibilityGate(
        scoreCap: 0.52,
        feedbackMessage: 'Kaki belum terbaca jelas',
        missingLandmarks: missingRequired,
      );
    }
    if (visibleArms < 3) {
      return _PoseVisibilityGate(
        scoreCap: 0.58,
        feedbackMessage: 'Tangan belum terbaca jelas',
        missingLandmarks: missingRequired,
      );
    }

    return const _PoseVisibilityGate(scoreCap: 1);
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
        if (!_ignoredLandmarks.contains(landmark.name) &&
            (landmark.visibility ?? 1) >= minimumVisibility)
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

    return ((pointScore * 0.50) + (directionScore * 0.25) + (angleScore * 0.25))
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

  double _computePositionScore({
    required List<PoseLandmark> referenceLandmarks,
    required List<PoseLandmark> candidateLandmarks,
  }) {
    final refBody = <String, PoseLandmark>{
      for (final l in referenceLandmarks)
        if (!_ignoredLandmarks.contains(l.name)) l.name: l,
    };
    final candBody = <String, PoseLandmark>{
      for (final l in candidateLandmarks)
        if (!_ignoredLandmarks.contains(l.name) &&
            (l.visibility ?? 1) >= minimumVisibility)
          l.name: l,
    };
    if (refBody.length < 4 || candBody.length < 4) return 0.5;

    double refMinX = double.infinity, refMaxX = double.negativeInfinity;
    double refMinY = double.infinity, refMaxY = double.negativeInfinity;
    double candMinX = double.infinity, candMaxX = double.negativeInfinity;
    double candMinY = double.infinity, candMaxY = double.negativeInfinity;

    for (final l in refBody.values) {
      refMinX = math.min(refMinX, l.x);
      refMaxX = math.max(refMaxX, l.x);
      refMinY = math.min(refMinY, l.y);
      refMaxY = math.max(refMaxY, l.y);
    }
    for (final l in candBody.values) {
      candMinX = math.min(candMinX, l.x);
      candMaxX = math.max(candMaxX, l.x);
      candMinY = math.min(candMinY, l.y);
      candMaxY = math.max(candMaxY, l.y);
    }

    final refCx = (refMinX + refMaxX) / 2;
    final refCy = (refMinY + refMaxY) / 2;
    final refW = refMaxX - refMinX;
    final refH = refMaxY - refMinY;
    final candCx = (candMinX + candMaxX) / 2;
    final candCy = (candMinY + candMaxY) / 2;
    final candW = candMaxX - candMinX;
    final candH = candMaxY - candMinY;

    final centerDist = math.sqrt(
      (refCx - candCx) * (refCx - candCx) +
          (refCy - candCy) * (refCy - candCy),
    );
    const maxExpectedDist = 0.25;
    final centerRatio = (centerDist / maxExpectedDist).clamp(0.0, 1.0);
    final centerScore = (1 - centerRatio).clamp(0.0, 1.0);

    final refArea = refW * refH;
    final candArea = candW * candH;
    final areaRatio = refArea > 0 && candArea > 0
        ? math.min(refArea, candArea) / math.max(refArea, candArea)
        : 0.0;

    final sizeDiffW = refW > 0 ? (refW - candW).abs() / refW : 1.0;
    final sizeDiffH = refH > 0 ? (refH - candH).abs() / refH : 1.0;
    final sizeScore = (1 - ((sizeDiffW + sizeDiffH) / 2)).clamp(0.0, 1.0);

    return (centerScore * 0.50 + sizeScore * 0.30 + areaRatio * 0.20).clamp(0.0, 1.0);
  }

  double _distanceTolerance(String landmark) {
    if (_lowerBodyLandmarks.contains(landmark)) {
      return 0.95;
    }
    return 0.70;
  }

  double _landmarkWeight(String landmark) {
    if (_coreLandmarks.contains(landmark)) {
      return 1.15;
    }
    if (_lowerBodyLandmarks.contains(landmark)) {
      return 0.85;
    }
    return 1;
  }

  double _misalignmentThreshold(String landmark) {
    return _lowerBodyLandmarks.contains(landmark) ? 0.62 : 0.72;
  }

  double _segmentWeight(String segment) {
    if (segment == 'leftFoot' || segment == 'rightFoot') {
      return 0.50;
    }
    if (segment == 'leftLeg' || segment == 'rightLeg') {
      return 0.85;
    }
    if (segment == 'torso') {
      return 1.2;
    }
    return 1;
  }

  double _segmentMisalignmentThreshold(String segment) {
    if (segment == 'leftFoot' || segment == 'rightFoot') {
      return 0.50;
    }
    if (segment == 'leftLeg' || segment == 'rightLeg') {
      return 0.60;
    }
    return 0.72;
  }

  double _blockingSegmentThreshold(String segment) {
    if (segment == 'leftFoot' || segment == 'rightFoot') {
      return 0.40;
    }
    if (segment == 'leftLeg' || segment == 'rightLeg') {
      return 0.55;
    }
    if (segment == 'torso') {
      return 0.68;
    }
    return 0.78;
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

const Set<String> _coreLandmarks = <String>{
  'leftShoulder',
  'rightShoulder',
  'leftHip',
  'rightHip',
};

const Set<String> _requiredBodyLandmarks = <String>{
  'leftShoulder',
  'rightShoulder',
  'leftElbow',
  'rightElbow',
  'leftWrist',
  'rightWrist',
  'leftHip',
  'rightHip',
  'leftKnee',
  'rightKnee',
  'leftAnkle',
  'rightAnkle',
};

const Set<String> _requiredArmLandmarks = <String>{
  'leftElbow',
  'rightElbow',
  'leftWrist',
  'rightWrist',
};

const Set<String> _requiredLowerBodyLandmarks = <String>{
  'leftKnee',
  'rightKnee',
  'leftAnkle',
  'rightAnkle',
};

const Set<String> _lowerBodyLandmarks = <String>{
  'leftKnee',
  'rightKnee',
  'leftAnkle',
  'rightAnkle',
  'leftHeel',
  'rightHeel',
  'leftFootIndex',
  'rightFootIndex',
};

const Set<String> _ignoredLandmarks = <String>{
  'nose',
  'leftEyeInner',
  'leftEye',
  'leftEyeOuter',
  'rightEyeInner',
  'rightEye',
  'rightEyeOuter',
  'leftEar',
  'rightEar',
  'leftMouth',
  'rightMouth',
};

class _PoseVisibilityGate {
  const _PoseVisibilityGate({
    required this.scoreCap,
    this.feedbackMessage,
    this.missingLandmarks = const <String>[],
  });

  final double scoreCap;
  final String? feedbackMessage;
  final List<String> missingLandmarks;
}
