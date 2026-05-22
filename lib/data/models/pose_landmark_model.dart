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
    return PoseLandmark(
      name: name,
      x: x,
      y: y,
      z: z,
      visibility: visibility,
    );
  }

  factory PoseLandmarkModel.fromEntity(PoseLandmark landmark) {
    return PoseLandmarkModel(
      name: landmark.name,
      x: landmark.x,
      y: landmark.y,
      z: landmark.z,
      visibility: landmark.visibility,
    );
  }

  factory PoseLandmarkModel.fromJson(Map<String, dynamic> json) {
    return PoseLandmarkModel(
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num?)?.toDouble() ?? 0,
      visibility: (json['visibility'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'x': x,
      'y': y,
      'z': z,
      'visibility': visibility,
    };
  }
}
