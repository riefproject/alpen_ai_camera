import 'dart:ui';

import 'dart:async';

import 'package:camera/camera.dart' as camera;
import 'package:alpen_ai_camera/core/constants/app_constants.dart';
import 'package:alpen_ai_camera/domain/services/camera_service.dart';
import 'package:flutter/foundation.dart';

class CameraController extends ChangeNotifier {
  CameraController({required CameraService cameraService})
    : _cameraService = cameraService;

  // TODO: Orchestrate presentation state for camera readiness, capture actions, and error messages.
  final CameraService _cameraService;

  CameraService get cameraService => _cameraService;

  bool _isInitializing = false;
  bool _isCapturing = false;
  String? _errorMessage;
  camera.FlashMode _flashMode = camera.FlashMode.off;
  camera.FocusMode _focusMode = camera.FocusMode.auto;
  camera.ExposureMode _exposureMode = camera.ExposureMode.auto;
  double _currentZoomLevel = 1.0;
  Offset? _lastFocusPoint;
  double _currentExposureOffset = 0.0;
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _exposureOffsetStepSize = 0.0;

  camera.CameraController? get previewController => _cameraService.previewController;
  bool get isInitializing => _isInitializing;
  bool get isCapturing => _isCapturing;
  bool get isReady => _cameraService.isInitialized;
  bool get canSwitchCamera => _cameraService.availableCameras.length > 1;
  String? get errorMessage => _errorMessage;
  camera.FlashMode get flashMode => _flashMode;
  camera.FocusMode get focusMode => _focusMode;
  camera.ExposureMode get exposureMode => _exposureMode;
  double get currentZoomLevel => _currentZoomLevel;
  double get minHardwareZoomLevel => _cameraService.minZoomLevel;
  double get maxHardwareZoomLevel => _cameraService.maxZoomLevel;
  camera.CameraDescription? get currentCamera => _cameraService.currentCamera;
  Offset? get lastFocusPoint => _lastFocusPoint;
  double get currentExposureOffset => _currentExposureOffset;
  double get minExposureOffset => _minExposureOffset;
  double get maxExposureOffset => _maxExposureOffset;
  bool get supportsExposureOffset =>
      (_maxExposureOffset - _minExposureOffset).abs() > 0.001;
  bool get isFocusExposureLocked =>
      _focusMode == camera.FocusMode.locked &&
      _exposureMode == camera.ExposureMode.locked;

  String get statusLabel {
    if (_errorMessage != null) {
      return _errorMessage!;
    }
    if (_isCapturing) {
      return AppConstants.capturingStatusLabel;
    }
    if (_isInitializing) {
      return AppConstants.initializingStatusLabel;
    }
    if (isReady) {
      return AppConstants.readyStatusLabel;
    }

    return AppConstants.initialStatusLabel;
  }

  Future<void> initialize() async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _cameraService.initialize();
      await _cameraService.setFocusMode(camera.FocusMode.auto);
      await _cameraService.setExposureMode(camera.ExposureMode.auto);
      _focusMode = camera.FocusMode.auto;
      _exposureMode = camera.ExposureMode.auto;
      _lastFocusPoint = null;
      _lastAppliedZoomLevel = minHardwareZoomLevel.toDouble();
      _pendingZoomLevel = null;
      _pendingExposureOffset = null;
      _currentZoomLevel = _displayZoomForCurrentCamera(minHardwareZoomLevel);
      await _loadExposureCapabilities();
    } catch (error) {
      _errorMessage = 'Gagal menginisialisasi kamera: $error';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera || _isInitializing) {
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _cameraService.switchCamera();
      _currentZoomLevel = _displayZoomForCurrentCamera(minHardwareZoomLevel);
      await _cameraService.setFlashMode(_flashMode);
      await _cameraService.setFocusMode(camera.FocusMode.auto);
      await _cameraService.setExposureMode(camera.ExposureMode.auto);
      _focusMode = camera.FocusMode.auto;
      _exposureMode = camera.ExposureMode.auto;
      _lastFocusPoint = null;
      _lastAppliedZoomLevel = minHardwareZoomLevel.toDouble();
      _pendingZoomLevel = null;
      _pendingExposureOffset = null;
      _currentExposureOffset = 0.0;
      await _loadExposureCapabilities();
    } catch (error) {
      _errorMessage = 'Gagal mengganti kamera: $error';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<camera.XFile?> capturePhoto({Duration? delay}) async {
    if (!isReady || _isCapturing) {
      return null;
    }

    _isCapturing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (delay != null && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      return await _cameraService.takePicture();
    } catch (error) {
      _errorMessage = 'Gagal mengambil foto: $error';
      return null;
    } finally {
      _isCapturing = false;
      notifyListeners();
    }
  }

  Future<void> focusOnPoint(Offset point) async {
    if (!isReady) {
      return;
    }

    final normalizedPoint = Offset(
      point.dx.clamp(0.0, 1.0),
      point.dy.clamp(0.0, 1.0),
    );

    try {
      await _cameraService.setFocusMode(camera.FocusMode.auto);
      await _cameraService.setExposureMode(camera.ExposureMode.auto);
      await _cameraService.setExposurePoint(normalizedPoint);
      await _cameraService.setFocusPoint(normalizedPoint);
      _focusMode = camera.FocusMode.auto;
      _exposureMode = camera.ExposureMode.auto;
      _lastFocusPoint = normalizedPoint;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Gagal mengatur fokus: $error';
      notifyListeners();
    }
  }

  Future<void> toggleFocusExposureLock() async {
    if (!isReady) {
      return;
    }

    final shouldLock = !isFocusExposureLocked;

    try {
      await _cameraService.setFocusMode(
        shouldLock ? camera.FocusMode.locked : camera.FocusMode.auto,
      );
      await _cameraService.setExposureMode(
        shouldLock
            ? camera.ExposureMode.locked
            : camera.ExposureMode.auto,
      );
      _focusMode =
          shouldLock ? camera.FocusMode.locked : camera.FocusMode.auto;
      _exposureMode =
          shouldLock
              ? camera.ExposureMode.locked
              : camera.ExposureMode.auto;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Gagal mengubah lock fokus: $error';
      notifyListeners();
    }
  }

  Future<void> increaseExposureOffset() async {
    await _setExposureOffsetByDelta(_effectiveExposureStepSize);
  }

  Future<void> decreaseExposureOffset() async {
    await _setExposureOffsetByDelta(-_effectiveExposureStepSize);
  }

  bool _isApplyingExposureOffset = false;
  double? _pendingExposureOffset;
  double? _lastAppliedExposureOffset;

  Future<void> setExposureOffset(double offset) async {
    if (!isReady) return;

    final newOffset = offset.clamp(
      _minExposureOffset,
      _maxExposureOffset,
    ).toDouble();
    if ((_currentExposureOffset - newOffset).abs() < 0.0001) return;
    
    _currentExposureOffset = newOffset;
    notifyListeners();

    _pendingExposureOffset = newOffset;
    unawaited(_flushExposureOffset());
  }

  Future<void> _flushExposureOffset() async {
    if (_isApplyingExposureOffset || !isReady) {
      return;
    }

    _isApplyingExposureOffset = true;

    try {
      while (isReady && _pendingExposureOffset != null) {
        final target = _quantizeExposureOffset(_pendingExposureOffset!);

        if (_lastAppliedExposureOffset != null &&
            (_lastAppliedExposureOffset! - target).abs() < 0.0001) {
          if ((_quantizeExposureOffset(_pendingExposureOffset!) - target).abs() <
              0.0001) {
            _pendingExposureOffset = null;
          }
          continue;
        }

        _pendingExposureOffset = null;
        final applied = await _cameraService.setExposureOffset(target);
        _lastAppliedExposureOffset = applied;

        if (_pendingExposureOffset != null &&
            (_quantizeExposureOffset(_pendingExposureOffset!) - applied).abs() <
                0.0001) {
          _pendingExposureOffset = null;
        }
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Gagal mengatur offset eksposur: $e';
      notifyListeners();
    } finally {
      _isApplyingExposureOffset = false;

      if (_pendingExposureOffset != null && isReady) {
        unawaited(_flushExposureOffset());
      }
    }
  }

  Future<void> setFlashMode(camera.FlashMode mode) async {
    if (!isReady) {
      return;
    }

    try {
      await _cameraService.setFlashMode(mode);
      _flashMode = mode;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Gagal mengubah mode flash: $error';
      notifyListeners();
    }
  }

  bool _isApplyingZoomLevel = false;
  double? _pendingZoomLevel;
  double? _lastAppliedZoomLevel;

  Future<void> setZoomLevel(double zoom) async {
    if (!isReady) {
      return;
    }

    final currentCameraDescription = currentCamera;
    if (currentCameraDescription == null) {
      return;
    }

    final targetCamera = _resolveCameraForRequestedZoom(zoom);
    if (targetCamera != null && targetCamera != currentCameraDescription) {
      await _switchToCamera(targetCamera);
    }

    final currentBaseZoom = _displayBaseZoomForCamera(currentCamera);
    final targetUiZoom = zoom.clamp(minZoomLevel, maxZoomLevel).toDouble();
    final targetHardwareZoom = (targetUiZoom / currentBaseZoom).clamp(
      minHardwareZoomLevel,
      maxHardwareZoomLevel,
    ).toDouble();
    final targetDisplayZoom = targetHardwareZoom * currentBaseZoom;

    if ((_currentZoomLevel - targetDisplayZoom).abs() < 0.0001) return;

    _currentZoomLevel = targetDisplayZoom;
    notifyListeners();

    _pendingZoomLevel = targetHardwareZoom;
    unawaited(_flushZoomLevel());
  }

  Future<void> _flushZoomLevel() async {
    if (_isApplyingZoomLevel || !isReady) {
      return;
    }

    _isApplyingZoomLevel = true;

    try {
      while (isReady && _pendingZoomLevel != null) {
        final target = _pendingZoomLevel!;
        _pendingZoomLevel = null;

        if (_lastAppliedZoomLevel != null &&
            (_lastAppliedZoomLevel! - target).abs() < 0.0001) {
          continue;
        }

        await _cameraService.setZoomLevel(target);
        _lastAppliedZoomLevel = target;
      }
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Gagal mengubah zoom: $error';
      notifyListeners();
    } finally {
      _isApplyingZoomLevel = false;

      if (_pendingZoomLevel != null && isReady) {
        unawaited(_flushZoomLevel());
      }
    }
  }

  Future<void> _loadExposureCapabilities() async {
    try {
      _minExposureOffset = await _cameraService.getMinExposureOffset();
      _maxExposureOffset = await _cameraService.getMaxExposureOffset();
      _exposureOffsetStepSize =
          await _cameraService.getExposureOffsetStepSize();
      _currentExposureOffset = 0.0;
      _lastAppliedExposureOffset = 0.0;
      _pendingExposureOffset = null;
    } catch (_) {
      _minExposureOffset = 0.0;
      _maxExposureOffset = 0.0;
      _exposureOffsetStepSize = 0.0;
      _currentExposureOffset = 0.0;
      _lastAppliedExposureOffset = 0.0;
      _pendingExposureOffset = null;
    }
  }

  double get _effectiveExposureStepSize {
    if (_exposureOffsetStepSize > 0) {
      return _exposureOffsetStepSize;
    }

    final range = (_maxExposureOffset - _minExposureOffset).abs();
    if (range <= 0.001) {
      return 0.0;
    }

    return range / 12;
  }

  Future<void> _setExposureOffsetByDelta(double delta) async {
    if (!isReady || !supportsExposureOffset || delta == 0) {
      return;
    }

    final target = (_currentExposureOffset + delta).clamp(
      _minExposureOffset,
      _maxExposureOffset,
    );

    await setExposureOffset(target.toDouble());
  }

  double get minZoomLevel {
    final ultraWideCamera = _findBackCameraByLensType(
      camera.CameraLensType.ultraWide,
    );
    if (ultraWideCamera != null) {
      return _displayBaseZoomForCamera(ultraWideCamera);
    }

    return _displayZoomForCurrentCamera(minHardwareZoomLevel);
  }

  double get maxZoomLevel => _displayZoomForCurrentCamera(maxHardwareZoomLevel);

  double get wideZoomPreset => minZoomLevel;

  double get standardZoomPreset {
    if (minZoomLevel <= 1.0 && maxZoomLevel >= 1.0) {
      return 1.0;
    }
    return minZoomLevel;
  }

  double get teleZoomPreset {
    if (minZoomLevel <= 2.0 && maxZoomLevel >= 2.0) {
      return 2.0;
    }
    return maxZoomLevel;
  }

  Future<void> _switchToCamera(camera.CameraDescription description) async {
    await _cameraService.setActiveCamera(description);
    await _cameraService.setFlashMode(_flashMode);
    await _cameraService.setFocusMode(_focusMode);
    await _cameraService.setExposureMode(_exposureMode);
    _lastAppliedZoomLevel = minHardwareZoomLevel.toDouble();
    _pendingZoomLevel = null;
    _currentZoomLevel = _displayZoomForCurrentCamera(minHardwareZoomLevel);
  }

  camera.CameraDescription? _resolveCameraForRequestedZoom(double requestedZoom) {
    final current = currentCamera;
    if (current == null ||
        current.lensDirection != camera.CameraLensDirection.back) {
      return current;
    }

    if (requestedZoom < 1.0) {
      return _findBackCameraByLensType(camera.CameraLensType.ultraWide) ??
          current;
    }

    return _findBackCameraByLensType(camera.CameraLensType.wide) ??
        _findBackCameraByLensType(camera.CameraLensType.unknown) ??
        current;
  }

  camera.CameraDescription? _findBackCameraByLensType(
    camera.CameraLensType lensType,
  ) {
    for (final cameraDescription in _cameraService.availableCameras) {
      if (cameraDescription.lensDirection == camera.CameraLensDirection.back &&
          cameraDescription.lensType == lensType) {
        return cameraDescription;
      }
    }

    return null;
  }

  double _displayBaseZoomForCamera(camera.CameraDescription? description) {
    if (description?.lensType == camera.CameraLensType.ultraWide) {
      return 0.6;
    }

    return 1.0;
  }

  double _displayZoomForCurrentCamera(double hardwareZoom) {
    return hardwareZoom * _displayBaseZoomForCamera(currentCamera);
  }

  double _quantizeExposureOffset(double value) {
    final step = _effectiveExposureStepSize;
    if (step <= 0) {
      return value;
    }

    final inv = 1 / step;
    final snapped = (value * inv).roundToDouble() / inv;
    return snapped.clamp(_minExposureOffset, _maxExposureOffset).toDouble();
  }

  @override
  void dispose() {
    unawaited(_cameraService.dispose());
    super.dispose();
  }
}
