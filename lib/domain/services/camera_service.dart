import 'package:alpen_ai_camera/domain/entities/camera_session.dart';

abstract class CameraService {
  // TODO: Define the contract for camera lifecycle, capture flow, and resource cleanup.
  Future<CameraSession> initialize();
  Future<void> dispose();
}
