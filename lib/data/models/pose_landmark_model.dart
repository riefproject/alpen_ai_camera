import 'package:alpen_ai_camera/domain/entities/pose_landmark.dart';

class PoseLandmarkModel {
  const PoseLandmarkModel({
    required this.name,
    required this.x,
    required this.y,
    this.z = 0,
    this.visibility,
  });

  // TODO: Adapt provider-specific landmark payloads into the stable domain landmark contract.
  final String name;
  final double x;
  final double y;
  final double z;
  final double? visibility;

  PoseLandmark toEntity() {
    throw UnimplementedError(
      'PoseLandmarkModel.toEntity belum diimplementasikan.',
    );
  }
}
