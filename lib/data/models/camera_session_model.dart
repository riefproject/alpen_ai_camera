import 'package:alpen_ai_camera/domain/entities/camera_session.dart';

class CameraSessionModel {
  const CameraSessionModel({
    required this.id,
    required this.active,
    required this.createdAt,
  });

  // TODO: Adapt raw camera/session payloads into the domain entity shape.
  final String id;
  final bool active;
  final DateTime createdAt;

  CameraSession toEntity() {
    throw UnimplementedError(
      'CameraSessionModel.toEntity belum diimplementasikan.',
    );
  }
}
