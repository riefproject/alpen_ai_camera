import 'dart:async';
import 'dart:typed_data';

import 'package:alpen_ai_camera/data/datasources/camera/camera_frame_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/pose_match_result.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/domain/services/camera_service.dart';
import 'package:alpen_ai_camera/domain/use_cases/analyze_live_pose_use_case.dart';
import 'package:alpen_ai_camera/domain/use_cases/build_pose_template_from_upload_use_case.dart';
import 'package:flutter/foundation.dart';

enum PoseWorkflowStatus {
  inactive,
  loadingTemplate,
  tracking,
  matched,
  uploading,
  error,
}

class PoseWorkflowController extends ChangeNotifier {
  PoseWorkflowController({
    required CameraService cameraService,
    required AnalyzeLivePoseUseCase analyzeLivePoseUseCase,
    required BuildPoseTemplateFromUploadUseCase
        buildPoseTemplateFromUploadUseCase,
    required Future<void> Function() capturePhoto,
  })  : _cameraService = cameraService,
        _analyzeLivePoseUseCase = analyzeLivePoseUseCase,
        _buildPoseTemplateFromUploadUseCase = buildPoseTemplateFromUploadUseCase,
        _capturePhoto = capturePhoto;

  static const Duration _frameInterval = Duration(milliseconds: 100);
  static const Duration _autoCaptureHold = Duration(milliseconds: 800);
  static const Duration _autoCaptureCooldown = Duration(seconds: 3);

  final CameraService _cameraService;
  final AnalyzeLivePoseUseCase _analyzeLivePoseUseCase;
  final BuildPoseTemplateFromUploadUseCase _buildPoseTemplateFromUploadUseCase;
  final Future<void> Function() _capturePhoto;

  PoseWorkflowStatus _status = PoseWorkflowStatus.inactive;
  List<PoseTemplate> _templates = const <PoseTemplate>[];
  PoseTemplate? _selectedTemplate;
  PoseMatchResult? _lastMatchResult;
  String? _errorMessage;
  String? _lastRawError;
  String? _lightingFeedback;
  bool _autoCaptureEnabled = false;
  bool _isProcessingFrame = false;
  DateTime? _lastProcessedAt;
  DateTime? _matchedSince;
  DateTime? _lastAutoCapturedAt;
  StreamSubscription<CameraFramePayload>? _frameSubscription;

  PoseWorkflowStatus get status => _status;
  bool get isActive => _status != PoseWorkflowStatus.inactive;
  bool get isTracking =>
      _status == PoseWorkflowStatus.tracking ||
      _status == PoseWorkflowStatus.matched;
  bool get isMatched => _lastMatchResult?.isMatched ?? false;
  bool get autoCaptureEnabled => _autoCaptureEnabled;
  List<PoseTemplate> get templates => List<PoseTemplate>.unmodifiable(_templates);
  PoseTemplate? get selectedTemplate => _selectedTemplate;
  PoseMatchResult? get lastMatchResult => _lastMatchResult;
  double get score => _lastMatchResult?.score ?? 0;
  String? get errorMessage => _errorMessage;
  String? get lastRawError => _lastRawError;
  String? get lightingFeedback => _lightingFeedback;
  String get feedbackMessage =>
      _errorMessage ?? _lastMatchResult?.feedbackMessage ?? 'Pilih pose';

  Future<void> toggle() async {
    if (isActive) {
      await stop();
      return;
    }

    await start();
  }

  Future<void> start() async {
    if (isActive) {
      return;
    }

    _status = PoseWorkflowStatus.loadingTemplate;
    _errorMessage = null;
    notifyListeners();

    try {
      await refreshTemplates();
      if (_templates.isEmpty) {
        throw StateError('Belum ada template pose.');
      }

      _selectedTemplate ??= _templates.first;
      _status = PoseWorkflowStatus.tracking;
      _frameSubscription =
          _cameraService.startImageStream().listen(_handleFrame);
    } catch (error) {
      _status = PoseWorkflowStatus.error;
      _lastRawError = error.toString();
      _errorMessage = _friendlyError(error);
    }

    notifyListeners();
  }

  Future<void> refreshTemplates() async {
    _templates =
        await _analyzeLivePoseUseCase.poseRepository.getAvailableTemplates();
    if (_selectedTemplate != null) {
      for (final template in _templates) {
        if (template.templateId == _selectedTemplate!.templateId) {
          _selectedTemplate = template;
          return;
        }
      }
    }
    _selectedTemplate ??= _templates.isEmpty ? null : _templates.first;
  }

  Future<void> stop() async {
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _cameraService.stopImageStream();
    _status = PoseWorkflowStatus.inactive;
    _lastMatchResult = null;
    _lightingFeedback = null;
    _matchedSince = null;
    _errorMessage = null;
    _lastRawError = null;
    notifyListeners();
  }

  Future<void> suspendTrackingForCapture() async {
    if (!isTracking) {
      return;
    }

    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _cameraService.stopImageStream();
    _isProcessingFrame = false;
  }

  Future<void> resumeTrackingAfterCapture() async {
    if (!isActive || _status == PoseWorkflowStatus.inactive) {
      return;
    }

    if (_frameSubscription != null) {
      return;
    }

    _status = PoseWorkflowStatus.tracking;
    _frameSubscription = _cameraService.startImageStream().listen(_handleFrame);
    notifyListeners();
  }

  Future<void> selectTemplate(PoseTemplate template) async {
    _selectedTemplate = template;
    _lastMatchResult = null;
    _matchedSince = null;
    if (isActive && _status != PoseWorkflowStatus.uploading) {
      _status = PoseWorkflowStatus.tracking;
    }
    notifyListeners();
  }

  void setAutoCaptureEnabled(bool enabled) {
    if (_autoCaptureEnabled == enabled) {
      return;
    }

    _autoCaptureEnabled = enabled;
    _matchedSince = null;
    notifyListeners();
  }

  Future<void> buildTemplateFromUpload(String imagePath) async {
    final wasActive = isActive;
    if (wasActive) {
      await suspendTrackingForCapture();
    }
    _status = PoseWorkflowStatus.uploading;
    _errorMessage = null;
    notifyListeners();

    try {
      final template = await _buildPoseTemplateFromUploadUseCase(
        imagePath: imagePath,
        templateName: 'Pose Upload ${_templates.length + 1}',
      );
      _templates = <PoseTemplate>[
        ...await _analyzeLivePoseUseCase.poseRepository.getAvailableTemplates(),
      ];
      _selectedTemplate = template;
      _errorMessage = null;
      _lastRawError = null;
      _lastMatchResult = null;
      _matchedSince = null;
      _status = wasActive ? PoseWorkflowStatus.tracking : PoseWorkflowStatus.inactive;
      if (wasActive) {
        await resumeTrackingAfterCapture();
      }
    } catch (error) {
      _status = wasActive ? PoseWorkflowStatus.error : PoseWorkflowStatus.inactive;
      _lastRawError = error.toString();
      _errorMessage = _friendlyError(error);
    }

    notifyListeners();
  }

  Future<void> _handleFrame(CameraFramePayload frame) async {
    if (_isProcessingFrame || _selectedTemplate == null) {
      return;
    }

    final now = DateTime.now();
    final lastProcessedAt = _lastProcessedAt;
    if (lastProcessedAt != null &&
        now.difference(lastProcessedAt) < _frameInterval) {
      return;
    }

    _isProcessingFrame = true;
    _lastProcessedAt = now;

    try {
      _lightingFeedback = _detectBacklight(frame.bytes);
      final result = await _analyzeLivePoseUseCase(
        templateId: _selectedTemplate!.templateId,
        frameBytes: frame.bytes,
        width: frame.width,
        height: frame.height,
        rotationDegrees: frame.rotationDegrees,
        formatRaw: frame.formatRaw,
        bytesPerRow: frame.bytesPerRow,
      );
      _lastMatchResult = result;
      _status = result.isMatched
          ? PoseWorkflowStatus.matched
          : PoseWorkflowStatus.tracking;
      await _maybeAutoCapture(result);
      notifyListeners();
    } catch (error) {
      final diagnostic = frame.diagnosticLabel == null
          ? error.toString()
          : '${frame.diagnosticLabel}: $error';
      debugPrint('Pose frame gagal diproses: $diagnostic');
      _lastRawError = diagnostic;
      _lastMatchResult = const PoseMatchResult(
        isMatched: false,
        score: 0,
        feedbackMessage: 'Pose belum terbaca',
      );
      _status = PoseWorkflowStatus.tracking;
      _errorMessage = null;
      notifyListeners();
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _maybeAutoCapture(PoseMatchResult result) async {
    if (!_autoCaptureEnabled || !result.isMatched) {
      _matchedSince = null;
      return;
    }

    final now = DateTime.now();
    _matchedSince ??= now;
    if (now.difference(_matchedSince!) < _autoCaptureHold) {
      return;
    }

    final lastAutoCapturedAt = _lastAutoCapturedAt;
    if (lastAutoCapturedAt != null &&
        now.difference(lastAutoCapturedAt) < _autoCaptureCooldown) {
      return;
    }

    _lastAutoCapturedAt = now;
    await suspendTrackingForCapture();
    await _capturePhoto();
    await resumeTrackingAfterCapture();
  }

  String? _detectBacklight(Uint8List bytes) {
    if (bytes.isEmpty) {
      return null;
    }

    final sampleStep = (bytes.length / 1600).ceil().clamp(1, bytes.length);
    var bright = 0;
    var dark = 0;
    var total = 0;
    for (var index = 0; index < bytes.length; index += sampleStep) {
      final value = bytes[index];
      if (value > 220) {
        bright++;
      } else if (value < 45) {
        dark++;
      }
      total++;
    }

    if (total == 0) {
      return null;
    }

    final brightRatio = bright / total;
    final darkRatio = dark / total;
    if (brightRatio > 0.34 && darkRatio > 0.18) {
      return 'Cahaya belakang terlalu terang';
    }

    return null;
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('lebih dari satu pose')) {
      return 'Gambar terlalu ramai. Pilih satu orang saja.';
    }
    if (message.contains('tidak terdeteksi') ||
        message.contains('kurang jelas') ||
        message.contains('tidak cukup jelas')) {
      return 'Pose tidak jelas. Pilih gambar dengan tubuh terlihat penuh.';
    }
    if (message.contains('terlalu kecil') || message.contains('terlihat penuh')) {
      return 'Tubuh tidak terlihat penuh.';
    }
    if (message.contains('background terlalu ramai') ||
        message.contains('terlalu penuh')) {
      return 'Background terlalu ramai untuk dijadikan pose.';
    }
    if (message.contains('Outline tubuh')) {
      return 'Outline tubuh tidak terbaca dari gambar.';
    }
    if (message.contains('Template pose')) {
      return 'Template pose tidak ditemukan.';
    }
    return 'Pose assistant belum bisa memproses gambar ini.';
  }

  @override
  void dispose() {
    unawaited(_frameSubscription?.cancel());
    unawaited(_cameraService.stopImageStream());
    super.dispose();
  }
}
