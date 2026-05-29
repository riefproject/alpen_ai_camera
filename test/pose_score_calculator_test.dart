import 'package:alpen_ai_camera/core/math/pose_score_calculator.dart';
import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';
import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = PoseScoreCalculator();

  test('returns matched result for identical normalized poses', () {
    final landmarks = _bodyLandmarks();
    final result = calculator.calculate(
      referencePose: PoseTemplate(
        templateId: 'test',
        name: 'Test',
        landmarks: landmarks,
      ),
      candidatePose: PoseFrame(
        frameId: 'frame',
        landmarks: landmarks,
        width: 100,
        height: 100,
        capturedAt: DateTime(2026),
      ),
    );

    expect(result.isMatched, isTrue);
    expect(result.score, greaterThanOrEqualTo(0.9));
    expect(result.landmarkScores['leftWrist'], greaterThanOrEqualTo(0.95));
    expect(result.segmentScores['leftLowerArm'], greaterThanOrEqualTo(0.95));
  });

  test('is resilient to simple scale and translation differences', () {
    final reference = _bodyLandmarks();
    final candidate = reference
        .map(
          (landmark) => PoseLandmark(
            name: landmark.name,
            x: (landmark.x * 1.4) + 0.1,
            y: (landmark.y * 1.4) + 0.05,
            visibility: landmark.visibility,
          ),
        )
        .toList();

    final result = calculator.calculate(
      referencePose: PoseTemplate(
        templateId: 'test',
        name: 'Test',
        landmarks: reference,
      ),
      candidatePose: PoseFrame(
        frameId: 'frame',
        landmarks: candidate,
        width: 100,
        height: 100,
        capturedAt: DateTime(2026),
      ),
    );

    expect(result.score, greaterThan(0.85));
  });

  test('accepts horizontally mirrored candidates for front camera', () {
    final reference = _bodyLandmarks();
    final mirrored = reference
        .map(
          (landmark) => PoseLandmark(
            name: landmark.name,
            x: 1 - landmark.x,
            y: landmark.y,
            visibility: landmark.visibility,
          ),
        )
        .toList();

    final result = calculator.calculate(
      referencePose: PoseTemplate(
        templateId: 'test',
        name: 'Test',
        landmarks: reference,
      ),
      candidatePose: PoseFrame(
        frameId: 'frame',
        landmarks: mirrored,
        width: 100,
        height: 100,
        capturedAt: DateTime(2026),
      ),
    );

    expect(result.isMatched, isTrue);
    expect(
      result.candidateLandmarks
          .firstWhere((landmark) => landmark.name == 'leftShoulder')
          .x,
      closeTo(
        reference.firstWhere((landmark) => landmark.name == 'leftShoulder').x,
        0.001,
      ),
    );
  });

  test('scores a misaligned limb lower than matching segments', () {
    final reference = _bodyLandmarks();
    final candidate = reference
        .map(
          (landmark) => landmark.name == 'rightWrist'
              ? const PoseLandmark(
                  name: 'rightWrist',
                  x: 0.20,
                  y: 0.18,
                  visibility: 1,
                )
              : landmark,
        )
        .toList();

    final result = calculator.calculate(
      referencePose: PoseTemplate(
        templateId: 'test',
        name: 'Test',
        landmarks: reference,
      ),
      candidatePose: PoseFrame(
        frameId: 'frame',
        landmarks: candidate,
        width: 100,
        height: 100,
        capturedAt: DateTime(2026),
      ),
    );

    expect(result.isMatched, isFalse);
    expect(result.misalignedLandmarks, contains('rightWrist'));
    expect(result.segmentScores['rightLowerArm'], lessThan(0.68));
    expect(result.segmentScores['leftLowerArm'], greaterThan(0.9));
  });

  test('rejects pose with too few visible body landmarks', () {
    final result = calculator.calculate(
      referencePose: PoseTemplate(
        templateId: 'test',
        name: 'Test',
        landmarks: _bodyLandmarks(),
      ),
      candidatePose: PoseFrame(
        frameId: 'frame',
        landmarks: const <PoseLandmark>[
          PoseLandmark(name: 'nose', x: 0.5, y: 0.2),
        ],
        width: 100,
        height: 100,
        capturedAt: DateTime(2026),
      ),
    );

    expect(result.isMatched, isFalse);
    expect(result.score, 0);
  });

  test('caps score when lower body is not visible', () {
    final reference = _bodyLandmarks();
    final upperBodyOnly = reference
        .where(
          (landmark) => !<String>{
            'leftKnee',
            'rightKnee',
            'leftAnkle',
            'rightAnkle',
          }.contains(landmark.name),
        )
        .toList();

    final result = calculator.calculate(
      referencePose: PoseTemplate(
        templateId: 'test',
        name: 'Test',
        landmarks: reference,
      ),
      candidatePose: PoseFrame(
        frameId: 'frame',
        landmarks: upperBodyOnly,
        width: 100,
        height: 100,
        capturedAt: DateTime(2026),
      ),
    );

    expect(result.isMatched, isFalse);
    expect(result.score, lessThanOrEqualTo(0.34));
    expect(result.feedbackMessage, 'Pastikan tubuh terlihat penuh');
  });
}

List<PoseLandmark> _bodyLandmarks() {
  return const <PoseLandmark>[
    PoseLandmark(name: 'nose', x: 0.50, y: 0.15, visibility: 1),
    PoseLandmark(name: 'leftShoulder', x: 0.38, y: 0.28, visibility: 1),
    PoseLandmark(name: 'rightShoulder', x: 0.62, y: 0.28, visibility: 1),
    PoseLandmark(name: 'leftElbow', x: 0.30, y: 0.43, visibility: 1),
    PoseLandmark(name: 'rightElbow', x: 0.70, y: 0.43, visibility: 1),
    PoseLandmark(name: 'leftWrist', x: 0.42, y: 0.53, visibility: 1),
    PoseLandmark(name: 'rightWrist', x: 0.58, y: 0.53, visibility: 1),
    PoseLandmark(name: 'leftHip', x: 0.43, y: 0.55, visibility: 1),
    PoseLandmark(name: 'rightHip', x: 0.57, y: 0.55, visibility: 1),
    PoseLandmark(name: 'leftKnee', x: 0.42, y: 0.78, visibility: 1),
    PoseLandmark(name: 'rightKnee', x: 0.58, y: 0.78, visibility: 1),
    PoseLandmark(name: 'leftAnkle', x: 0.40, y: 0.96, visibility: 1),
    PoseLandmark(name: 'rightAnkle', x: 0.60, y: 0.96, visibility: 1),
  ];
}
