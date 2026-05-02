import 'package:alpen_ai_camera/core/constants/app_constants.dart';
import 'package:alpen_ai_camera/domain/services/camera_service.dart';
import 'package:flutter/foundation.dart';

class CameraController extends ChangeNotifier {
  CameraController({required CameraService cameraService})
    : _cameraService = cameraService;

  // TODO: Orchestrate presentation state for camera readiness, capture actions, and error messages.
  final CameraService _cameraService;

  CameraService get cameraService => _cameraService;
  String get statusLabel => AppConstants.initialStatusLabel;
}
