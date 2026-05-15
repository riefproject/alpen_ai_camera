import 'dart:ui';

import 'package:camera/camera.dart' as camera;

import 'package:alpen_ai_camera/domain/entities/camera_session.dart';

abstract class CameraService {
  // TODO: Define the contract for camera lifecycle, capture flow, and resource cleanup.
  camera.CameraController? get previewController;
  camera.CameraDescription? get currentCamera;
  CameraSession? get activeSession;
  List<camera.CameraDescription> get availableCameras;
  bool get isInitialized;
  double get minZoomLevel;
  double get maxZoomLevel;

  Future<CameraSession> initialize({int cameraIndex = 0});
  Future<void> switchCamera();
  Future<void> setActiveCamera(camera.CameraDescription description);
  Future<void> setFlashMode(camera.FlashMode mode);
  Future<void> setFocusMode(camera.FocusMode mode);
  Future<void> setFocusPoint(Offset? point);
  Future<void> setExposureMode(camera.ExposureMode mode);
  Future<void> setExposurePoint(Offset? point);
  Future<double> getMinExposureOffset();
  Future<double> getMaxExposureOffset();
  Future<double> getExposureOffsetStepSize();
  Future<double> setExposureOffset(double offset);
  Future<void> setZoomLevel(double zoomLevel);
  Future<camera.XFile> takePicture();
  Future<void> dispose();
}
