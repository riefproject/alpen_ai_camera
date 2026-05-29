import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'package:alpen_ai_camera/core/math/pose_score_calculator.dart';
import 'package:alpen_ai_camera/data/datasources/image_processing/image_preprocessor_datasource.dart';
import 'package:alpen_ai_camera/data/datasources/local/pose_template_local_datasource.dart';
import 'package:alpen_ai_camera/data/datasources/ml/pose_detector_datasource.dart';
import 'package:alpen_ai_camera/data/repositories_impl/pose_repository_impl.dart';
import 'package:alpen_ai_camera/data/services_impl/camera_service_impl.dart';
import 'package:alpen_ai_camera/data/services_impl/pose_detector_service_impl.dart';
import 'package:alpen_ai_camera/data/services_impl/pose_outline_builder_service_impl.dart';
import 'package:alpen_ai_camera/data/services_impl/pose_template_builder_service_impl.dart';
import 'package:alpen_ai_camera/domain/use_cases/analyze_live_pose_use_case.dart';
import 'package:alpen_ai_camera/domain/use_cases/build_pose_template_from_upload_use_case.dart';
import 'package:alpen_ai_camera/presentation/controllers/camera_controller.dart'
    as app_camera;
import 'package:alpen_ai_camera/presentation/controllers/pose_workflow_controller.dart';
import 'package:alpen_ai_camera/presentation/screens/pose_library_screen.dart';
import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/filter_applier.dart';
import '../widgets/pose_ghost_overlay.dart';
import 'gallery_screen.dart';

// GPU-accelerated filter using dart:ui ColorFilter
Future<Uint8List?> _applyFilterWithGpu(Uint8List imageBytes, List<double> matrix) async {
  final codec = await ui.instantiateImageCodec(imageBytes);
  final frame = await codec.getNextFrame();
  final srcImage = frame.image;
  final width = srcImage.width;
  final height = srcImage.height;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix);
  canvas.drawImage(srcImage, ui.Offset.zero, paint);
  srcImage.dispose();

  final picture = recorder.endRecording();
  final dstImage = await picture.toImage(width, height);
  picture.dispose();

  final byteData = await dstImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  dstImage.dispose();
  if (byteData == null) return null;

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    byteData.buffer.asUint8List(), width, height,
    ui.PixelFormat.rgba8888, completer.complete,
  );
  final finalImg = await completer.future;
  final pngData = await finalImg.toByteData(format: ui.ImageByteFormat.png);
  finalImg.dispose();
  return pngData?.buffer.asUint8List();
}

// Widget Jangka Sorong (Ruler) sederhana untuk Zoom
class ZoomRuler extends StatefulWidget {
  final double min;
  final double max;
  final double initialValue;
  final ValueChanged<double> onChanged;

  const ZoomRuler({
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
    super.key,
  });

  @override
  State<ZoomRuler> createState() => _ZoomRulerState();
}

class _ZoomRulerState extends State<ZoomRuler> {
  late ScrollController _scrollController;
  final double _itemWidth = 10.0;
  final int _divisions = 100; // Pembagian titik ukur

  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    // Hitung posisi awal berdasarkan initialValue
    double initialOffset =
        ((widget.initialValue - widget.min) / (widget.max - widget.min)) *
        (_divisions * _itemWidth);
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_isUserScrolling) {
      return; // Prevent feedback loop from programmatic jumps
    }
    double offset = _scrollController.offset;
    double maxOffset = _divisions * _itemWidth;
    double percent = (offset / maxOffset).clamp(0.0, 1.0);
    double value = widget.min + (percent * (widget.max - widget.min));
    widget.onChanged(value);
  }

  @override
  void didUpdateWidget(covariant ZoomRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && !_isUserScrolling) {
      double targetOffset =
          ((widget.initialValue - widget.min) / (widget.max - widget.min)) *
          (_divisions * _itemWidth);
      if (_scrollController.hasClients) {
        if ((_scrollController.offset - targetOffset).abs() > 1.0) {
          _scrollController.jumpTo(targetOffset);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30, // lebih slim
      child: Stack(
        alignment: Alignment.center,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notif) {
              if (notif is ScrollStartNotification &&
                  notif.dragDetails != null) {
                _isUserScrolling = true;
              } else if (notif is ScrollEndNotification) {
                _isUserScrolling = false;
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _divisions + 30, // Extra padding
              itemBuilder: (context, index) {
                if (index < 15 || index > _divisions + 15) {
                  return SizedBox(width: _itemWidth); // Padding pinggir
                }
                int tickIndex = index - 15;
                bool isMajor = tickIndex % 10 == 0;
                return SizedBox(
                  width: _itemWidth,
                  child: Center(
                    child: Container(
                      width: 1.0,
                      height: isMajor ? 14 : 7,
                      color: isMajor ? Colors.white : Colors.white54,
                    ),
                  ),
                );
              },
            ),
          ),
          // Indikator tengah
          Container(width: 2, height: 20, color: Colors.yellowAccent),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({super.key});

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen> {
  late final app_camera.CameraController _cameraController;
  late final PoseWorkflowController _poseController;
  late final CameraServiceImpl _cameraService;
  late final MlKitPoseDetectorDataSource _poseDetectorDataSource;
  late final PoseOutlineBuilderServiceImpl _poseOutlineBuilderService;
  Offset? _focusIndicatorPosition;
  String _activeTopMenu = 'none';
  String _aspectRatio = '4:3';
  String _hdrMode = 'AUTO';
  int _timer = 0;
  bool _showFilters = false;
  bool _showTopSettings = false; // Panel atas
  bool _showDetectedPoseSkeleton = false;
  String _selectedFilter = 'Asli';

  final List<String> _filters = [
    'Asli',
    'Alami',
    'Manis',
    'Keriangan',
    'Kristal',
  ];

  camera.CameraController? get _previewController =>
      _cameraController.previewController;

  String? _latestPhotoPath;
  bool _isFlashing = false;
  bool _isGalleryBlinking = false;
  bool _isCapturingHardware = false;

  @override
  void initState() {
    super.initState();
    _cameraService = CameraServiceImpl();
    _cameraController = app_camera.CameraController(
      cameraService: _cameraService,
    );
    final poseRepository = PoseRepositoryImpl(
      localDataSource: HivePoseTemplateLocalDataSource(),
    );
    _poseDetectorDataSource = MlKitPoseDetectorDataSource();
    final poseDetectorService = PoseDetectorServiceImpl(
      poseDetectorDataSource: _poseDetectorDataSource,
    );
    _poseOutlineBuilderService = PoseOutlineBuilderServiceImpl();
    final templateBuilderService = PoseTemplateBuilderServiceImpl(
      imagePreprocessorDataSource:
          const PassthroughImagePreprocessorDataSource(),
      poseDetectorService: poseDetectorService,
      poseOutlineBuilderService: _poseOutlineBuilderService,
    );
    _poseController = PoseWorkflowController(
      cameraService: _cameraService,
      analyzeLivePoseUseCase: AnalyzeLivePoseUseCase(
        poseRepository: poseRepository,
        poseDetectorService: poseDetectorService,
        poseScoreCalculator: const PoseScoreCalculator(),
      ),
      buildPoseTemplateFromUploadUseCase: BuildPoseTemplateFromUploadUseCase(
        poseRepository: poseRepository,
        poseTemplateBuilderService: templateBuilderService,
      ),
      capturePhoto: _capturePhoto,
    );
    _cameraController.initialize();
    _loadLatestPhoto();
  }

  Future<void> _loadLatestPhoto() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>()
          .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
          .toList();
      if (files.isNotEmpty) {
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        if (mounted) setState(() => _latestPhotoPath = files.first.path);
      }
    } catch (e) {
      debugPrint('Gagal memuat foto terakhir: $e');
    }
  }

  Future<void> _toggleCamera() async {
    await _cameraController.switchCamera();
    if (!mounted) {
      return;
    }

    setState(() {
      _focusIndicatorPosition = null;
    });
  }

  Future<void> _capturePhoto() async {
    final shouldResumePose = _poseController.isTracking;
    if (_isCapturingHardware) return;

    // Quick white flash feedback IMMEDIATELY when user taps shutter
    if (mounted) {
      setState(() {
        _isCapturingHardware = true;
        _isFlashing = true;
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) setState(() => _isFlashing = false);
      });
    }

    camera.XFile? photo;
    try {
      if (shouldResumePose) {
        await _poseController.suspendTrackingForCapture();
      }

      photo = await _cameraController.capturePhoto(
        delay: _timer > 0 ? Duration(seconds: _timer) : null,
      );
    } catch (e) {
      debugPrint('Gagal capture hardware: $e');
    } finally {
      if (mounted) setState(() => _isCapturingHardware = false);
      if (shouldResumePose) {
        await _poseController.resumeTrackingAfterCapture();
      }
    }

    if (photo == null) return;

    // Process + save in background
    _processAndSavePhotoInBackground(photo, _selectedFilter);
  }

  Future<void> _processAndSavePhotoInBackground(camera.XFile photo, String filterName) async {
    try {
      // 1. Save original to system gallery without blocking
      Gal.putImage(photo.path).catchError((e) {
        debugPrint('Gal save error: $e');
      });

      // 2. Immediately copy original photo to app directory so gallery icon updates instantly
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final finalPath = '${dir.path}/$fileName';
      await File(photo.path).copy(finalPath);

      if (mounted) {
        setState(() {
          _latestPhotoPath = finalPath;
          _isGalleryBlinking = true;
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _isGalleryBlinking = false);
        });
      }

      // 3. If there is a filter, process it asynchronously and overwrite the file when done
      final filterMatrix = filterName.toLowerCase() != 'asli'
          ? FilterApplier.getFilterMatrix(filterName)
          : null;

      if (filterMatrix != null) {
        _applyAndSaveFilterAsync(photo.path, finalPath, filterMatrix);
      }
    } catch (e) {
      debugPrint('Gagal memproses foto di background: $e');
    }
  }

  // Runs the heavy filter logic completely detached from the main capture flow
  Future<void> _applyAndSaveFilterAsync(String sourcePath, String destPath, List<double> matrix) async {
    try {
      final imageBytes = await File(sourcePath).readAsBytes();
      final processedBytes = await _applyFilterWithGpu(imageBytes, matrix);
      if (processedBytes != null) {
        await File(destPath).writeAsBytes(processedBytes);
      }
    } catch (e) {
      debugPrint('Gagal apply filter: $e');
    }
  }

  Future<void> _togglePoseAssistant() async {
    await _poseController.toggle();
    if (!mounted) {
      return;
    }

    setState(() {
      _activeTopMenu = 'none';
      _showTopSettings = false;
      _showFilters = false;
    });
  }

  Future<void> _openPoseLibrary() async {
    await _poseController.refreshTemplates();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => PoseLibraryScreen(controller: _poseController),
      ),
    );
  }

  void _toggleDetectedPoseSkeleton() {
    setState(() {
      _showDetectedPoseSkeleton = !_showDetectedPoseSkeleton;
    });
  }

  Future<void> _openGallery() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GalleryScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _setFlashMode(camera.FlashMode mode) async {
    await _cameraController.setFlashMode(mode);
    if (!mounted) {
      return;
    }

    setState(() {
      _activeTopMenu = 'none';
    });
  }

  void _setZoom(double zoom) {
    _cameraController.setZoomLevel(zoom);
  }

  Future<void> _handlePreviewTap(
    TapDownDetails details,
    BoxConstraints constraints,
  ) async {
    final normalizedPoint = Offset(
      (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
      (details.localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0),
    );

    setState(() {
      _focusIndicatorPosition = details.localPosition;
      _showFilters = false;
      _activeTopMenu = 'none';
      _showTopSettings = false;
    });

    await _cameraController.focusOnPoint(normalizedPoint);
  }

  Widget _buildInteractivePreview({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final accentColor = _cameraController.isFocusExposureLocked
            ? Colors.lightGreenAccent
            : Colors.yellowAccent;

        bool isTooRight = false;
        double sliderLeft = 0;
        double lockLeft = 0;
        double lockTop = 0;

        if (_focusIndicatorPosition != null) {
          isTooRight = _focusIndicatorPosition!.dx > constraints.maxWidth - 100;
          // Kalau terlalu ke kanan, slider di kiri fokus, sebaliknya di kanan
          if (isTooRight) {
            sliderLeft = _focusIndicatorPosition!.dx - 64;
          } else {
            sliderLeft = _focusIndicatorPosition!.dx + 48;
          }
          // Lock icon di atas slider brightness
          lockLeft =
              sliderLeft +
              3; // Nengahin icon dengan slider (width 30, icon width 24)
          lockTop =
              _focusIndicatorPosition!.dy -
              85; // Di atas slider (height 120 -> center at dy, top is dy - 60)
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => _handlePreviewTap(details, constraints),
                child: child,
              ),
            ),
            if (_focusIndicatorPosition != null) ...[
              // Focus Box
              Positioned(
                left: _focusIndicatorPosition!.dx - 32,
                top: _focusIndicatorPosition!.dy - 32,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CustomPaint(
                      painter: _MinimalistFocusPainter(color: accentColor),
                    ),
                  ),
                ),
              ),
              // Lock Icon (Above brightness slider)
              Positioned(
                left: lockLeft,
                top: lockTop,
                child: GestureDetector(
                  onTap: () {
                    _cameraController.toggleFocusExposureLock();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _cameraController.isFocusExposureLocked
                          ? Icons.lock
                          : Icons.lock_open,
                      color: accentColor,
                      size: 16,
                    ),
                  ),
                ),
              ),
              // Exposure Slider
              if (_cameraController.supportsExposureOffset)
                Positioned(
                  left: sliderLeft,
                  top: _focusIndicatorPosition!.dy - 60,
                  child: SizedBox(
                    height: 120,
                    width: 30,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vertical thin line
                        Container(
                          width: 1,
                          height: 120,
                          color: accentColor.withValues(alpha: 0.6),
                        ),
                        // Slider
                        RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 0,
                              activeTrackColor: Colors.transparent,
                              inactiveTrackColor: Colors.transparent,
                              thumbShape: _SunThumbShape(color: accentColor),
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: _cameraController.currentExposureOffset,
                              min: _cameraController.minExposureOffset,
                              max: _cameraController.maxExposureOffset,
                              onChanged: (val) {
                                _cameraController.setExposureOffset(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            // Removed old `_buildFocusAssistControls` call
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _poseController.dispose();
    _poseDetectorDataSource.close();
    _poseOutlineBuilderService.close();
    _cameraController.dispose();
    super.dispose();
  }

  void _toggleTopSettings() {
    setState(() {
      _showTopSettings = !_showTopSettings;
      _activeTopMenu = 'none';
      if (_showTopSettings) _showFilters = false;
    });
  }

  Widget _buildTopSettingsPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEE1A1A1A), // Dark transparent
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pengatur Waktu',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              Row(
                children: [
                  _buildTopTimerOption(0, Icons.timer_off),
                  const SizedBox(width: 8),
                  _buildTopTimerOption(3, Icons.timer_3),
                  const SizedBox(width: 8),
                  _buildTopTimerOption(10, Icons.timer_10),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pengaturan',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                onPressed: () {
                  setState(() => _showTopSettings = false);
                  // To real settings...
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: _toggleTopSettings,
              child: Container(
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTimerOption(int value, IconData icon) {
    bool isSelected = _timer == value;
    return GestureDetector(
      onTap: () {
        setState(() => _timer = value);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFFD4E157) : Colors.white24,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRatioIcon(String ratio, {bool isSelected = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.crop_free,
          color: isSelected ? Colors.black : Colors.white,
          size: 28,
        ),
        Text(
          ratio,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRatioOption(String value, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _aspectRatio = value;
          _activeTopMenu = 'none';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4E157) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _buildRatioIcon(value, isSelected: isSelected),
      ),
    );
  }

  Widget _buildTopBarMenu() {
    if (_activeTopMenu == 'flash') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            'Flash',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          _buildFlashOption(camera.FlashMode.off, Icons.flash_off),
          _buildFlashOption(camera.FlashMode.always, Icons.flash_on),
          _buildFlashOption(camera.FlashMode.auto, Icons.flash_auto),
          _buildFlashOption(camera.FlashMode.torch, Icons.highlight),
        ],
      );
    } else if (_activeTopMenu == 'hdr') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            'HDR',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          _buildTextOption('hdr', 'OFF', _hdrMode == 'OFF'),
          _buildTextOption('hdr', 'ON', _hdrMode == 'ON'),
          _buildTextOption('hdr', 'AUTO', _hdrMode == 'AUTO'),
        ],
      );
    } else if (_activeTopMenu == 'ratio') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text(
            'Rasio aspek',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          _buildRatioOption('1:1', _aspectRatio == '1:1'),
          _buildRatioOption('4:3', _aspectRatio == '4:3'),
          _buildRatioOption('16:9', _aspectRatio == '16:9'),
          _buildRatioOption('Full', _aspectRatio == 'Full'),
        ],
      );
    }

    IconData getFlashIcon() {
      switch (_cameraController.flashMode) {
        case camera.FlashMode.off:
          return Icons.flash_off;
        case camera.FlashMode.always:
          return Icons.flash_on;
        case camera.FlashMode.auto:
          return Icons.flash_auto;
        case camera.FlashMode.torch:
          return Icons.highlight;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => setState(() => _activeTopMenu = 'flash'),
          child: Icon(getFlashIcon(), color: Colors.white, size: 24),
        ),
        GestureDetector(
          onTap: () => setState(() => _activeTopMenu = 'hdr'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HDR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_hdrMode != 'ON')
                Text(
                  _hdrMode,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _togglePoseAssistant,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _poseController.isActive
                    ? Colors.yellowAccent
                    : Colors.white,
                width: 1.5,
              ),
            ),
            child: Text(
              'AI',
              style: TextStyle(
                color: _poseController.isActive
                    ? Colors.yellowAccent
                    : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _activeTopMenu = 'ratio'),
          child: _buildRatioIcon(
            _aspectRatio == 'Full' ? 'Full' : _aspectRatio,
          ),
        ),
        GestureDetector(
          onTap: _toggleTopSettings,
          child: Icon(
            _showTopSettings ? Icons.close : Icons.more_vert,
            color: Colors.white,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildFlashOption(camera.FlashMode mode, IconData icon) {
    bool isSelected = _cameraController.flashMode == mode;
    return GestureDetector(
      onTap: () => _setFlashMode(mode),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFFD4E157) : Colors.white24,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTextOption(String type, String value, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (type == 'hdr') _hdrMode = value;
          if (type == 'ratio') _aspectRatio = value;
          _activeTopMenu = 'none';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? const Color(0xFFD4E157) : Colors.white24,
        ),
        child: Text(
          value,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildZoomAndWandOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris khusus Zoom Slider (Jangka Sorong)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_cameraController.currentZoomLevel.toStringAsFixed(1)}X',
                style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ZoomRuler(
                  min: _cameraController.minZoomLevel,
                  max: _cameraController.maxZoomLevel,
                  initialValue: _cameraController.currentZoomLevel,
                  onChanged: _setZoom,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Baris tombol overlay icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _openPoseLibrary,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black26,
                  ),
                  child: const Icon(
                    Icons.accessibility_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _setZoom(_cameraController.wideZoomPreset),
                      child: const Icon(
                        Icons.park,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () =>
                          _setZoom(_cameraController.standardZoomPreset),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${_cameraController.currentZoomLevel.toStringAsFixed(1)}X',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => _setZoom(_cameraController.teleZoomPreset),
                      child: const Icon(
                        Icons.nature,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showFilters = true),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black26,
                  ),
                  child: const Icon(
                    Icons.auto_fix_high,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildPoseGhostOverlay() {
    final template = _poseController.selectedTemplate;
    if (!_poseController.isActive || template == null) {
      return null;
    }
    
    final previewSize = _previewController?.value.previewSize;
    final size = previewSize != null ? Size(previewSize.height, previewSize.width) : null;

    return PoseGhostOverlay(
      template: template,
      matchResult: _poseController.lastMatchResult,
      showCandidateSkeleton: _showDetectedPoseSkeleton,
      previewSize: size,
    );
  }

  List<Widget> _buildPoseUIWidgets() {
    final template = _poseController.selectedTemplate;
    if (!_poseController.isActive || template == null) {
      return const <Widget>[];
    }

    return <Widget>[
      Positioned(
        top: _aspectRatio == 'Full' ? 72 : 12,
        left: 12,
        right: 12,
        child: Row(
          children: [
            GestureDetector(
              onTap: _openPoseLibrary,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.44),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.accessibility_new,
                      color: _poseController.isMatched
                          ? Colors.lightGreenAccent
                          : Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(_poseController.score * 100).round()}%',
                      style: TextStyle(
                        color: _poseController.isMatched
                            ? Colors.lightGreenAccent
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _toggleDetectedPoseSkeleton,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showDetectedPoseSkeleton
                      ? Colors.cyanAccent.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.36),
                  border: Border.all(
                    color: _showDetectedPoseSkeleton
                        ? Colors.cyanAccent
                        : Colors.white24,
                  ),
                ),
                child: Icon(
                  Icons.polyline,
                  color: _showDetectedPoseSkeleton
                      ? Colors.cyanAccent
                      : Colors.white70,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: IgnorePointer(
                child: Text(
                  _poseController.lightingFeedback ??
                      _poseController.feedbackMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildFilterCarousel() {
    final previewController = _previewController;
    if (previewController == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width:
                                previewController.value.previewSize?.height ??
                                1,
                            height:
                                previewController.value.previewSize?.width ?? 1,
                            child: FilterApplier(
                              filterName: filter,
                              child: camera.CameraPreview(previewController),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridLines() {
    return Column(
      children: [
        Expanded(child: Container()),
        Container(height: 1, color: Colors.white30),
        Expanded(child: Container()),
        Container(height: 1, color: Colors.white30),
        Expanded(child: Container()),
      ],
    );
  }

  Widget _buildGridLinesVertical() {
    return Row(
      children: [
        Expanded(child: Container()),
        Container(width: 1, color: Colors.white30),
        Expanded(child: Container()),
        Container(width: 1, color: Colors.white30),
        Expanded(child: Container()),
      ],
    );
  }

  double _getAspectRatio() {
    switch (_aspectRatio) {
      case '1:1':
        return 1.0;
      case '16:9':
        return 9 / 16;
      case 'Full':
      case '4:3':
      default:
        return 3 / 4;
    }
  }

  void _closeTransientCameraUi() {
    if (_showFilters) {
      setState(() => _showFilters = false);
    }
    if (_activeTopMenu != 'none') {
      setState(() => _activeTopMenu = 'none');
    }
    if (_showTopSettings) {
      setState(() => _showTopSettings = false);
    }
  }

  Widget _buildBottomUI() {
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: _showFilters
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Percantik',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Filter',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox(),
        ),

        const SizedBox(height: 20),

        // Tombol Kamera Bawah
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tombol Galeri
              GestureDetector(
                onTap: _openGallery,
                child: AnimatedOpacity(
                  opacity: _isGalleryBlinking ? 0.2 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[900],
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: ClipOval(
                      child: _latestPhotoPath != null
                          ? Image.file(
                              File(_latestPhotoPath!),
                              fit: BoxFit.cover,
                              width: 50,
                              height: 50,
                              gaplessPlayback: true,
                            )
                          : const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),

              // Tombol Shutter
              SizedBox(
                width: 80,
                height: 80,
                child: Center(
                  child: GestureDetector(
                    onTap: _capturePhoto,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: _isCapturingHardware ? 70 : 80,
                      height: _isCapturingHardware ? 70 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: _isCapturingHardware ? 56 : 66,
                          height: _isCapturingHardware ? 56 : 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturingHardware
                                ? Colors.grey
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Flip Kamera
              GestureDetector(
                onTap: _toggleCamera,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.sync, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        _cameraController,
        _poseController,
      ]),
      builder: (context, child) {
        final previewController = _previewController;
        if (!_cameraController.isReady || previewController == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cameraController.isInitializing)
                    const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _cameraController.statusLabel,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final cameraContent = FilterApplier(
          filterName: _selectedFilter,
          child: camera.CameraPreview(previewController),
        );

        return Stack(
          children: [
            Scaffold(
              backgroundColor: Colors.black,
          body: SafeArea(
            child: _aspectRatio == 'Full'
                ? Stack(
                    children: [
                      SizedBox.expand(
                        child: _buildInteractivePreview(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width:
                                  previewController.value.previewSize?.height ??
                                  1,
                              height:
                                  previewController.value.previewSize?.width ??
                                  1,
                              child: cameraContent,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            height: 60,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: _buildTopBarMenu(),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _closeTransientCameraUi,
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _buildGridLines()),
                                  Positioned.fill(
                                    child: _buildGridLinesVertical(),
                                  ),
                                  ..._buildPoseUIWidgets(),
                                  Positioned(
                                    bottom: 20,
                                    left: 0,
                                    right: 0,
                                    child: _showFilters
                                        ? _buildFilterCarousel()
                                        : _buildZoomAndWandOverlay(),
                                  ),
                                  if (_showTopSettings)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      child: _buildTopSettingsPanel(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            padding: const EdgeInsets.only(bottom: 30, top: 15),
                            child: _buildBottomUI(),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        color: Colors.black,
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: _buildTopBarMenu(),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _closeTransientCameraUi,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                color: Colors.black,
                                width: double.infinity,
                                height: double.infinity,
                                child: Center(
                                  child: _aspectRatio == '16:9'
                                      ? SizedBox(
                                          width: double.infinity,
                                          height:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              16 /
                                              9,
                                          child: _buildInteractivePreview(
                                            child: FittedBox(
                                              fit: BoxFit.cover,
                                              child: SizedBox(
                                                width:
                                                    previewController
                                                        .value
                                                        .previewSize
                                                        ?.height ??
                                                    1,
                                                height:
                                                    previewController
                                                        .value
                                                        .previewSize
                                                        ?.width ??
                                                    1,
                                                child: Stack(
                                                  children: [
                                                    cameraContent,
                                                    if (_buildPoseGhostOverlay() != null)
                                                      Positioned.fill(child: _buildPoseGhostOverlay()!),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : AspectRatio(
                                          aspectRatio: _getAspectRatio(),
                                          child: _buildInteractivePreview(
                                            child: ClipRect(
                                              child: FittedBox(
                                                fit: BoxFit.cover,
                                                child: SizedBox(
                                                  width:
                                                      previewController
                                                          .value
                                                          .previewSize
                                                          ?.height ??
                                                      1,
                                                  height:
                                                      previewController
                                                          .value
                                                          .previewSize
                                                          ?.width ??
                                                      1,
                                                  child: Stack(
                                                    children: [
                                                      cameraContent,
                                                      if (_buildPoseGhostOverlay() != null)
                                                        Positioned.fill(child: _buildPoseGhostOverlay()!),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned.fill(child: _buildGridLines()),
                              Positioned.fill(child: _buildGridLinesVertical()),
                              ..._buildPoseUIWidgets(),
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: _showFilters
                                    ? _buildFilterCarousel()
                                    : _buildZoomAndWandOverlay(),
                              ),
                              if (_showTopSettings)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildTopSettingsPanel(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.only(bottom: 30, top: 15),
                        child: _buildBottomUI(),
                      ),
                    ],
                  ),
            ), // End SafeArea
            ), // End Scaffold
            // WHITE FLASH on capture
            if (_isFlashing)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _isFlashing ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 50),
                    child: Container(color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MinimalistFocusPainter extends CustomPainter {
  _MinimalistFocusPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final length = size.width * 0.25;

    canvas.drawLine(const Offset(0, 0), Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, length), paint);

    // Top right corner
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - length, 0),
      paint,
    );
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - length),
      paint,
    );

    // Bottom right corner
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - length, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - length),
      paint,
    );

    // Center circle
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 4, paint);
  }

  @override
  bool shouldRepaint(covariant _MinimalistFocusPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SunThumbShape extends SliderComponentShape {
  const _SunThumbShape({required this.color});

  final Color color;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(20, 20);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 4, paint);

    const rayLength = 3.0;
    const innerRadius = 6.0;
    for (var index = 0; index < 8; index++) {
      final angle = index * (math.pi / 4);
      final dx1 = math.cos(angle) * innerRadius;
      final dy1 = math.sin(angle) * innerRadius;
      final dx2 = math.cos(angle) * (innerRadius + rayLength);
      final dy2 = math.sin(angle) * (innerRadius + rayLength);

      canvas.drawLine(
        Offset(center.dx + dx1, center.dy + dy1),
        Offset(center.dx + dx2, center.dy + dy2),
        paint,
      );
    }
  }
}
