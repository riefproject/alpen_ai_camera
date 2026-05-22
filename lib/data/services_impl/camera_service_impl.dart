import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:alpen_ai_camera/data/datasources/camera/camera_frame_datasource.dart';
import 'package:camera/camera.dart' as camera;

import 'package:alpen_ai_camera/domain/entities/camera_session.dart';
import 'package:alpen_ai_camera/domain/services/camera_service.dart';

class CameraServiceImpl implements CameraService {
  CameraServiceImpl();

  // TODO: Integrate camera plugin, permissions, and native resources in this implementation.
  static const double _defaultMinZoomLevel = 1.0;
  static const double _defaultMaxZoomLevel = 10.0;

  camera.CameraController? _previewController;
  List<camera.CameraDescription> _availableCameras = <camera.CameraDescription>[];
  CameraSession? _activeSession;
  int _activeCameraIndex = 0;
  double _minZoomLevel = _defaultMinZoomLevel;
  double _maxZoomLevel = _defaultMaxZoomLevel;
  StreamController<CameraFramePayload>? _imageStreamController;

  @override
  camera.CameraController? get previewController => _previewController;

  @override
  camera.CameraDescription? get currentCamera =>
      _availableCameras.isEmpty ? null : _availableCameras[_activeCameraIndex];

  @override
  CameraSession? get activeSession => _activeSession;

  @override
  List<camera.CameraDescription> get availableCameras =>
      List<camera.CameraDescription>.unmodifiable(_availableCameras);

  @override
  bool get isInitialized => _previewController?.value.isInitialized ?? false;

  @override
  double get minZoomLevel => _minZoomLevel;

  @override
  double get maxZoomLevel => _maxZoomLevel;

  @override
  Future<CameraSession> initialize({int cameraIndex = 0}) async {
    if (_availableCameras.isEmpty) {
      _availableCameras = await camera.availableCameras();
    }

    if (_availableCameras.isEmpty) {
      throw StateError('Tidak ada kamera yang tersedia di perangkat ini.');
    }

    _activeCameraIndex = _resolveInitialCameraIndex(cameraIndex);
    await _bindCamera(_availableCameras[_activeCameraIndex]);

    final session = CameraSession(
      sessionId:
          'camera-${DateTime.now().microsecondsSinceEpoch}-$_activeCameraIndex',
      isActive: true,
      createdAt: DateTime.now(),
    );

    _activeSession = session;
    return session;
  }

  @override
  Future<void> switchCamera() async {
    if (_availableCameras.length < 2) {
      return;
    }

    final nextIndex = (_activeCameraIndex + 1) % _availableCameras.length;
    _activeCameraIndex = nextIndex;
    await _bindCamera(_availableCameras[_activeCameraIndex]);
    _activeSession = CameraSession(
      sessionId:
          'camera-${DateTime.now().microsecondsSinceEpoch}-$nextIndex',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> setActiveCamera(camera.CameraDescription description) async {
    if (_availableCameras.isEmpty) {
      _availableCameras = await camera.availableCameras();
    }

    final nextIndex = _availableCameras.indexOf(description);
    if (nextIndex < 0) {
      throw StateError('Kamera target tidak ditemukan.');
    }

    if (nextIndex == _activeCameraIndex && isInitialized) {
      return;
    }

    _activeCameraIndex = nextIndex;
    await _bindCamera(_availableCameras[_activeCameraIndex]);
    _activeSession = CameraSession(
      sessionId:
          'camera-${DateTime.now().microsecondsSinceEpoch}-$nextIndex',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> setFlashMode(camera.FlashMode mode) async {
    final controller = _requireController();
    await controller.setFlashMode(mode);
  }

  @override
  Future<void> setFocusMode(camera.FocusMode mode) async {
    final controller = _requireController();
    await controller.setFocusMode(mode);
  }

  @override
  Future<void> setFocusPoint(Offset? point) async {
    final controller = _requireController();
    await controller.setFocusPoint(point);
  }

  @override
  Future<void> setExposureMode(camera.ExposureMode mode) async {
    final controller = _requireController();
    await controller.setExposureMode(mode);
  }

  @override
  Future<void> setExposurePoint(Offset? point) async {
    final controller = _requireController();
    await controller.setExposurePoint(point);
  }

  @override
  Future<double> getMinExposureOffset() async {
    final controller = _requireController();
    return controller.getMinExposureOffset();
  }

  @override
  Future<double> getMaxExposureOffset() async {
    final controller = _requireController();
    return controller.getMaxExposureOffset();
  }

  @override
  Future<double> getExposureOffsetStepSize() async {
    final controller = _requireController();
    return controller.getExposureOffsetStepSize();
  }

  @override
  Future<double> setExposureOffset(double offset) async {
    final controller = _requireController();
    return controller.setExposureOffset(offset);
  }

  @override
  Future<void> setZoomLevel(double zoomLevel) async {
    final controller = _requireController();
    final safeZoom =
        zoomLevel.clamp(_minZoomLevel, _maxZoomLevel).toDouble();
    await controller.setZoomLevel(safeZoom);
  }

  @override
  Stream<CameraFramePayload> startImageStream() {
    final controller = _requireController();
    if (_imageStreamController != null) {
      return _imageStreamController!.stream;
    }

    final streamController = StreamController<CameraFramePayload>.broadcast(
      onCancel: () {
        if (!(_imageStreamController?.hasListener ?? false)) {
          unawaited(stopImageStream());
        }
      },
    );
    _imageStreamController = streamController;

    controller.startImageStream((image) {
      if (streamController.isClosed) {
        return;
      }

      streamController.add(_cameraImageToPayload(image));
    });

    return streamController.stream;
  }

  @override
  Future<void> stopImageStream() async {
    final streamController = _imageStreamController;
    _imageStreamController = null;

    final controller = _previewController;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }

    await streamController?.close();
  }

  @override
  Future<camera.XFile> takePicture() async {
    final controller = _requireController();
    return controller.takePicture();
  }

  @override
  Future<void> dispose() async {
    await stopImageStream();
    final controller = _previewController;
    _previewController = null;
    _activeSession = null;
    _minZoomLevel = _defaultMinZoomLevel;
    _maxZoomLevel = _defaultMaxZoomLevel;

    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _bindCamera(camera.CameraDescription description) async {
    await stopImageStream();
    final previousController = _previewController;
    final nextController = camera.CameraController(
      description,
      camera.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? camera.ImageFormatGroup.nv21
          : camera.ImageFormatGroup.bgra8888,
    );

    _previewController = nextController;

    if (previousController != null) {
      await previousController.dispose();
    }

    await nextController.initialize();
    _minZoomLevel = await nextController.getMinZoomLevel();
    _maxZoomLevel = await nextController.getMaxZoomLevel();
  }

  CameraFramePayload _cameraImageToPayload(camera.CameraImage image) {
    if (Platform.isAndroid && image.planes.length == 3) {
      return CameraFramePayload(
        bytes: _yuv420ToNv21(image),
        width: image.width,
        height: image.height,
        rotationDegrees: currentCamera?.sensorOrientation ?? 0,
        formatRaw: 17,
        bytesPerRow: image.width,
        planeCount: image.planes.length,
        diagnosticLabel: 'android-yuv420-converted-nv21',
      );
    }

    if (image.planes.length == 1) {
      return CameraFramePayload(
        bytes: image.planes.first.bytes,
        width: image.width,
        height: image.height,
        rotationDegrees: currentCamera?.sensorOrientation ?? 0,
        formatRaw: image.format.raw,
        bytesPerRow: image.planes.first.bytesPerRow,
        planeCount: image.planes.length,
        diagnosticLabel: 'single-plane-${image.format.group.name}',
      );
    }

    return CameraFramePayload(
      bytes: Uint8List(0),
      width: image.width,
      height: image.height,
      rotationDegrees: currentCamera?.sensorOrientation ?? 0,
      formatRaw: image.format.raw,
      bytesPerRow: image.planes.isEmpty ? 0 : image.planes.first.bytesPerRow,
      planeCount: image.planes.length,
      diagnosticLabel: 'unsupported-${image.format.group.name}',
    );
  }

  Uint8List _yuv420ToNv21(camera.CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final output = Uint8List(width * height + (width * height ~/ 2));

    var outputIndex = 0;
    for (var row = 0; row < height; row++) {
      final rowOffset = row * yPlane.bytesPerRow;
      for (var col = 0; col < width; col++) {
        output[outputIndex++] = yPlane.bytes[rowOffset + col];
      }
    }

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < uvHeight; row++) {
      final uRowOffset = row * uPlane.bytesPerRow;
      final vRowOffset = row * vPlane.bytesPerRow;
      for (var col = 0; col < uvWidth; col++) {
        final uIndex = uRowOffset + col * uPixelStride;
        final vIndex = vRowOffset + col * vPixelStride;
        output[outputIndex++] = vPlane.bytes[vIndex];
        output[outputIndex++] = uPlane.bytes[uIndex];
      }
    }

    return output;
  }

  int _resolveInitialCameraIndex(int fallbackIndex) {
    final preferredWideBackIndex = _availableCameras.indexWhere(
      (cameraDescription) =>
          cameraDescription.lensDirection == camera.CameraLensDirection.back &&
          cameraDescription.lensType == camera.CameraLensType.wide,
    );
    if (preferredWideBackIndex >= 0) {
      return preferredWideBackIndex;
    }

    final anyBackIndex = _availableCameras.indexWhere(
      (cameraDescription) =>
          cameraDescription.lensDirection == camera.CameraLensDirection.back,
    );
    if (anyBackIndex >= 0) {
      return anyBackIndex;
    }

    return fallbackIndex.clamp(0, _availableCameras.length - 1);
  }

  camera.CameraController _requireController() {
    final controller = _previewController;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Kamera belum siap digunakan.');
    }

    return controller;
  }
}
