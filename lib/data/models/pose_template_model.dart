import 'package:alpen_ai_camera/data/models/pose_landmark_model.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

class PoseTemplateModel {
  const PoseTemplateModel({
    required this.id,
    required this.name,
    required this.landmarks,
    this.sourceImagePath,
  });

  // TODO: Adapt serialized or locally stored pose templates into the domain reference-pose structure.
  final String id;
  final String name;
  final List<PoseLandmarkModel> landmarks;
  final String? sourceImagePath;

  PoseTemplate toEntity() {
    throw UnimplementedError(
      'PoseTemplateModel.toEntity belum diimplementasikan.',
    );
  }
}
