import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:flutter/material.dart';

class PoseGhostOverlay extends StatelessWidget {
  const PoseGhostOverlay({required this.template, this.matchResult, super.key});

  final PoseTemplate template;
  final PoseMatchResult? matchResult;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: PoseGhostOverlayPainter(
          template: template,
          matchResult: matchResult,
          defaultColor: Colors.white,
          showCandidateSkeleton: false,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class PoseOutlinePreview extends StatelessWidget {
  const PoseOutlinePreview({
    required this.template,
    this.color = Colors.white,
    this.matchResult,
    this.showCandidateSkeleton = false,
    super.key,
  });

  final PoseTemplate template;
  final Color color;
  final PoseMatchResult? matchResult;
  final bool showCandidateSkeleton;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PoseGhostOverlayPainter(
        template: template,
        defaultColor: color,
        matchResult: matchResult,
        showCandidateSkeleton: showCandidateSkeleton,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class PoseGhostOverlayPainter extends CustomPainter {
  PoseGhostOverlayPainter({
    required this.template,
    required this.defaultColor,
    this.matchResult,
    this.showCandidateSkeleton = false,
  });

  final PoseTemplate template;
  final Color defaultColor;
  final PoseMatchResult? matchResult;
  final bool showCandidateSkeleton;

  @override
  void paint(Canvas canvas, Size size) {
    final points = template.outlinePoints.isNotEmpty
        ? template.outlinePoints
        : _outlineFromLandmarks(template.landmarks);
    if (points.length >= 3) {
      _drawOutline(canvas, size, points);
    }

    _drawSkeleton(
      canvas,
      size,
      landmarks: template.landmarks,
      segmentScores: matchResult?.segmentScores ?? const <String, double>{},
      landmarkScores: matchResult?.landmarkScores ?? const <String, double>{},
      isCandidate: false,
    );

    if (showCandidateSkeleton &&
        (matchResult?.candidateLandmarks.isNotEmpty ?? false)) {
      _drawSkeleton(
        canvas,
        size,
        landmarks: matchResult!.candidateLandmarks,
        segmentScores: const <String, double>{},
        landmarkScores: const <String, double>{},
        isCandidate: true,
      );
    }
  }

  void _drawOutline(Canvas canvas, Size size, List<PoseOutlinePoint> points) {
    final path = _buildSmoothPath(points, size);
    final outlineColor = _overallColor();
    final glowPaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.22)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final outlinePaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.88)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, outlinePaint);
  }

  void _drawSkeleton(
    Canvas canvas,
    Size size, {
    required List<PoseLandmark> landmarks,
    required Map<String, double> segmentScores,
    required Map<String, double> landmarkScores,
    required bool isCandidate,
  }) {
    final byName = <String, PoseLandmark>{
      for (final landmark in landmarks) landmark.name: landmark,
    };
    if (byName.isEmpty) {
      return;
    }

    for (final segment in _skeletonSegments.entries) {
      final points = segment.value
          .map((name) => byName[name])
          .whereType<PoseLandmark>()
          .toList();
      if (points.length < 2) {
        continue;
      }

      final color = isCandidate
          ? Colors.cyanAccent.withValues(alpha: 0.62)
          : _segmentColor(segment.key, segmentScores);
      final paint = Paint()
        ..color = color
        ..strokeWidth = isCandidate ? 2.2 : 4.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final glow = Paint()
        ..color = color.withValues(alpha: isCandidate ? 0.12 : 0.2)
        ..strokeWidth = isCandidate ? 5 : 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (var index = 1; index < points.length; index++) {
        final start = _projectLandmark(points[index - 1], size);
        final end = _projectLandmark(points[index], size);
        canvas.drawLine(start, end, glow);
        canvas.drawLine(start, end, paint);
      }
    }

    for (final landmark in byName.values) {
      final score = landmarkScores[landmark.name];
      final confidence = landmark.visibility ?? 1;
      final color = isCandidate
          ? Colors.cyanAccent.withValues(alpha: 0.62)
          : confidence < 0.35
          ? Colors.white38
          : _scoreColor(score);
      final center = _projectLandmark(landmark, size);
      canvas.drawCircle(
        center,
        isCandidate ? 3 : 4.2,
        Paint()..color = color.withValues(alpha: isCandidate ? 0.8 : 0.95),
      );
    }
  }

  Path _buildSmoothPath(List<PoseOutlinePoint> points, Size size) {
    final projected = points.map((point) => _project(point, size)).toList();
    final path = Path()..moveTo(projected.first.dx, projected.first.dy);

    for (var index = 1; index < projected.length; index++) {
      final previous = projected[index - 1];
      final current = projected[index];
      final midpoint = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(
        previous.dx,
        previous.dy,
        midpoint.dx,
        midpoint.dy,
      );
    }

    final last = projected.last;
    final first = projected.first;
    final closeMidpoint = Offset(
      (last.dx + first.dx) / 2,
      (last.dy + first.dy) / 2,
    );
    path.quadraticBezierTo(
      last.dx,
      last.dy,
      closeMidpoint.dx,
      closeMidpoint.dy,
    );
    path.close();
    return path;
  }

  Offset _project(PoseOutlinePoint point, Size size) {
    return Offset(
      point.x.clamp(0.0, 1.0) * size.width,
      point.y.clamp(0.0, 1.0) * size.height,
    );
  }

  Offset _projectLandmark(PoseLandmark landmark, Size size) {
    return Offset(
      landmark.x.clamp(0.0, 1.0) * size.width,
      landmark.y.clamp(0.0, 1.0) * size.height,
    );
  }

  Color _overallColor() {
    final score = matchResult?.score;
    if (score == null) {
      return defaultColor;
    }
    return _scoreColor(score);
  }

  Color _segmentColor(String segment, Map<String, double> segmentScores) {
    final score = segmentScores[segment];
    return _scoreColor(score);
  }

  Color _scoreColor(double? score) {
    if (score == null) {
      return defaultColor;
    }
    if (score >= 0.82) {
      return Colors.lightGreenAccent;
    }
    if (score >= 0.64) {
      return Colors.amberAccent;
    }
    return Colors.deepOrangeAccent;
  }

  List<PoseOutlinePoint> _outlineFromLandmarks(List<PoseLandmark> landmarks) {
    final byName = <String, PoseLandmark>{
      for (final landmark in landmarks) landmark.name: landmark,
    };
    final leftShoulder = byName['leftShoulder'];
    final rightShoulder = byName['rightShoulder'];
    final leftHip = byName['leftHip'];
    final rightHip = byName['rightHip'];
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return const <PoseOutlinePoint>[];
    }

    final top = byName['nose'] ?? leftShoulder;
    final leftAnkle = byName['leftAnkle'] ?? leftHip;
    final rightAnkle = byName['rightAnkle'] ?? rightHip;
    return <PoseOutlinePoint>[
      PoseOutlinePoint(x: top.x, y: (top.y - 0.08).clamp(0.0, 1.0)),
      PoseOutlinePoint(x: leftShoulder.x - 0.08, y: leftShoulder.y),
      PoseOutlinePoint(x: leftHip.x - 0.06, y: leftHip.y),
      PoseOutlinePoint(x: leftAnkle.x - 0.04, y: leftAnkle.y),
      PoseOutlinePoint(x: rightAnkle.x + 0.04, y: rightAnkle.y),
      PoseOutlinePoint(x: rightHip.x + 0.06, y: rightHip.y),
      PoseOutlinePoint(x: rightShoulder.x + 0.08, y: rightShoulder.y),
    ];
  }

  @override
  bool shouldRepaint(covariant PoseGhostOverlayPainter oldDelegate) {
    return oldDelegate.template != template ||
        oldDelegate.defaultColor != defaultColor ||
        oldDelegate.matchResult != matchResult ||
        oldDelegate.showCandidateSkeleton != showCandidateSkeleton;
  }
}

const Map<String, List<String>> _skeletonSegments = <String, List<String>>{
  'head': <String>['leftEar', 'leftEye', 'nose', 'rightEye', 'rightEar'],
  'shoulders': <String>['leftShoulder', 'rightShoulder'],
  'torso': <String>[
    'leftShoulder',
    'leftHip',
    'rightHip',
    'rightShoulder',
    'leftShoulder',
  ],
  'leftUpperArm': <String>['leftShoulder', 'leftElbow'],
  'leftLowerArm': <String>['leftElbow', 'leftWrist'],
  'rightUpperArm': <String>['rightShoulder', 'rightElbow'],
  'rightLowerArm': <String>['rightElbow', 'rightWrist'],
  'leftLeg': <String>['leftHip', 'leftKnee', 'leftAnkle'],
  'rightLeg': <String>['rightHip', 'rightKnee', 'rightAnkle'],
  'leftFoot': <String>['leftAnkle', 'leftHeel', 'leftFootIndex'],
  'rightFoot': <String>['rightAnkle', 'rightHeel', 'rightFootIndex'],
};
