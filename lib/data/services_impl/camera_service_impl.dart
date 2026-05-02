import 'package:alpen_ai_camera/domain/entities/camera_session.dart';
import 'package:alpen_ai_camera/domain/services/camera_service.dart';

class CameraServiceImpl implements CameraService {
  const CameraServiceImpl();

  // TODO: Integrate camera plugin, permissions, and native resources in this implementation.
  @override
  Future<CameraSession> initialize() {
    throw UnimplementedError(
      'CameraServiceImpl.initialize belum diimplementasikan.',
    );
  }

  @override
  Future<void> dispose() {
    throw UnimplementedError(
      'CameraServiceImpl.dispose belum diimplementasikan.',
    );
  }
}
