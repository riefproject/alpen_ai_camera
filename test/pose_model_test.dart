import 'package:alpen_ai_camera/data/models/pose_landmark_model.dart';
import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';
import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps pose landmark model to entity and json', () {
    const model = PoseLandmarkModel(
      name: 'leftShoulder',
      x: 0.25,
      y: 0.4,
      z: 0.1,
      visibility: 0.9,
    );

    final entity = model.toEntity();
    expect(entity.name, 'leftShoulder');
    expect(entity.x, 0.25);
    expect(entity.visibility, 0.9);

    final roundTrip = PoseLandmarkModel.fromJson(model.toJson());
    expect(roundTrip.name, model.name);
    expect(roundTrip.z, model.z);
  });

  test('maps pose template model to entity and json', () {
    const template = PoseTemplate(
      templateId: 'template-1',
      name: 'Pose Test',
      landmarks: <PoseLandmark>[
        PoseLandmark(name: 'nose', x: 0.5, y: 0.2),
      ],
      outlinePoints: <PoseOutlinePoint>[
        PoseOutlinePoint(x: 0.4, y: 0.1),
        PoseOutlinePoint(x: 0.3, y: 0.8),
        PoseOutlinePoint(x: 0.7, y: 0.8),
      ],
      sourceImagePath: '/tmp/pose.jpg',
    );

    final model = PoseTemplateModel.fromEntity(template);
    final entity = PoseTemplateModel.fromJson(model.toJson()).toEntity();

    expect(entity.templateId, template.templateId);
    expect(entity.name, template.name);
    expect(entity.landmarks.single.name, 'nose');
    expect(entity.outlinePoints.length, 3);
    expect(entity.sourceImagePath, template.sourceImagePath);
  });
}
