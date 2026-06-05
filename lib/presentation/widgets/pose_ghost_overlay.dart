import 'dart:math' as math;

import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:flutter/material.dart';

class PoseGhostOverlay extends StatelessWidget {
  const PoseGhostOverlay({
    required this.template,
    this.matchResult,
    this.showCandidateSkeleton = false,
    this.previewSize,
    super.key,
  });

  final PoseTemplate template;
  final PoseMatchResult? matchResult;
  final bool showCandidateSkeleton;
  final Size? previewSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: PoseGhostOverlayPainter(
          template: template,
          matchResult: matchResult,
          defaultColor: Colors.white,
          showCandidateSkeleton: showCandidateSkeleton,
          previewSize: previewSize,
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
    this.previewSize,
    super.key,
  });

  final PoseTemplate template;
  final Color color;
  final PoseMatchResult? matchResult;
  final bool showCandidateSkeleton;
  final Size? previewSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PoseGhostOverlayPainter(
        template: template,
        defaultColor: color,
        matchResult: matchResult,
        showCandidateSkeleton: showCandidateSkeleton,
        previewSize: previewSize,
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
    this.previewSize,
  });

  final PoseTemplate template;
  final Color defaultColor;
  final PoseMatchResult? matchResult;
  final bool showCandidateSkeleton;
  final Size? previewSize;

  // Transform for body-aware ghost scaling
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  void _computeTransform(Size canvasSize) {
    final bodyLandmarks = <PoseLandmark>[
      for (final l in template.landmarks)
        if (!_ignoredGhostLandmarks.contains(l.name)) l,
    ];
    if (bodyLandmarks.length < 4) {
      return;
    }

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final l in bodyLandmarks) {
      minX = math.min(minX, l.x);
      maxX = math.max(maxX, l.x);
      minY = math.min(minY, l.y);
      maxY = math.max(maxY, l.y);
    }
    // If candidate landmarks available, use their bounding box for positioning
    final candidateLandmarks = matchResult?.candidateLandmarks;
    if (candidateLandmarks != null && candidateLandmarks.isNotEmpty) {
      final candBody = <PoseLandmark>[
        for (final l in candidateLandmarks)
          if (!_ignoredGhostLandmarks.contains(l.name)) l,
      ];
      if (candBody.length >= 4) {
        double cMinX = double.infinity, cMaxX = double.negativeInfinity;
        double cMinY = double.infinity, cMaxY = double.negativeInfinity;
        for (final l in candBody) {
          cMinX = math.min(cMinX, l.x);
          cMaxX = math.max(cMaxX, l.x);
          cMinY = math.min(cMinY, l.y);
          cMaxY = math.max(cMaxY, l.y);
        }
        final candW = cMaxX - cMinX;
        final candH = cMaxY - cMinY;
        final candCx = (cMinX + cMaxX) / 2;
        final candCy = (cMinY + cMaxY) / 2;

        final bodyW = maxX - minX;
        final bodyH = maxY - minY;
        if (bodyW > 0 && bodyH > 0) {
          _scaleX = (candW / bodyW) * canvasSize.width;
          _scaleY = (candH / bodyH) * canvasSize.height;
          _offsetX = candCx * canvasSize.width - (minX + bodyW / 2) * _scaleX;
          _offsetY = candCy * canvasSize.height - (minY + bodyH / 2) * _scaleY;
          return;
        }
      }
    }

    // Default: scale template body to fill ~60% of canvas height
    final bodyH = maxY - minY;
    final bodyW = maxX - minX;
    if (bodyH <= 0 || bodyW <= 0) return;

    final targetHeight = canvasSize.height * 0.60;
    final targetWidth = canvasSize.width * 0.50;
    final scaleH = targetHeight / bodyH;
    final scaleW = targetWidth / bodyW;
    final uniformScale = math.min(scaleH, scaleW);

    final scaledW = bodyW * uniformScale;
    final scaledH = bodyH * uniformScale;

    _scaleX = uniformScale * canvasSize.width;
    _scaleY = uniformScale * canvasSize.height;
    _offsetX = (canvasSize.width - scaledW) / 2 - minX * _scaleX;
    _offsetY = (canvasSize.height - scaledH) / 2 - minY * _scaleY;
  }

  Offset _projectToCanvas(double nx, double ny) {
    return Offset(
      (nx * _scaleX + _offsetX).clamp(-10000.0, 10000.0),
      (ny * _scaleY + _offsetY).clamp(-10000.0, 10000.0),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _computeTransform(size);

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
      ..color = outlineColor.withValues(alpha: 0.12)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final outlinePaint = Paint()
      ..color = outlineColor.withValues(alpha: 0.58)
      ..strokeWidth = 2.6
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
          ? Colors.cyanAccent.withValues(alpha: 0.42)
          : _segmentColor(segment.key, segmentScores);
      final paint = Paint()
        ..color = color.withValues(alpha: isCandidate ? 0.48 : 0.64)
        ..strokeWidth = isCandidate ? 2.0 : 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final glow = Paint()
        ..color = color.withValues(alpha: isCandidate ? 0.08 : 0.12)
        ..strokeWidth = isCandidate ? 4.5 : 7
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
  }

  Path _buildSmoothPath(List<PoseOutlinePoint> points, Size size) {
    if (points.isEmpty) return Path();
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
    return _projectToCanvas(point.x, point.y);
  }

  Offset _projectLandmark(PoseLandmark landmark, Size size) {
    return _projectToCanvas(landmark.x, landmark.y);
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
        oldDelegate.showCandidateSkeleton != showCandidateSkeleton ||
        oldDelegate.previewSize != previewSize;
  }
}

const Set<String> _ignoredGhostLandmarks = <String>{
  'nose', 'leftEyeInner', 'leftEye', 'leftEyeOuter',
  'rightEyeInner', 'rightEye', 'rightEyeOuter',
  'leftEar', 'rightEar', 'leftMouth', 'rightMouth',
};

const Map<String, List<String>> _skeletonSegments = <String, List<String>>{
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
