import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alpen_ai_camera/core/utils/color_matrix_builder.dart';
import 'package:alpen_ai_camera/presentation/widgets/filter_applier.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';


// ─── Filter Preset Definition ───
class FilterPreset {
  final String name;
  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double highlights;
  final double shadows;
  final double temperature;
  final double tint;
  final double brilliance;
  final String? legacyFilterName; // For existing FilterApplier color matrices

  const FilterPreset({
    required this.name,
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.exposure = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.temperature = 0,
    this.tint = 0,
    this.brilliance = 0,
    this.legacyFilterName,
  });

  List<double> toMatrix() {
    if (legacyFilterName != null) {
      final m = FilterApplier.getFilterMatrix(legacyFilterName!);
      if (m != null) return m;
    }
    return ColorMatrixBuilder.buildCombined(
      brightnessVal: brightness,
      contrastVal: contrast,
      saturationVal: saturation,
      exposureVal: exposure,
      highlightsVal: highlights,
      shadowsVal: shadows,
      temperatureVal: temperature,
      tintVal: tint,
      brillianceVal: brilliance,
    );
  }
}

const List<FilterPreset> kFilterPresets = [
  FilterPreset(name: 'Asli'),
  FilterPreset(name: 'Alami', legacyFilterName: 'alami'),
  FilterPreset(name: 'Manis', legacyFilterName: 'manis'),
  FilterPreset(name: 'Keriangan', legacyFilterName: 'keriangan'),
  FilterPreset(name: 'Kristal', legacyFilterName: 'kristal'),
  FilterPreset(name: 'Sepia', legacyFilterName: 'sepia'),
  FilterPreset(name: 'B&W', legacyFilterName: 'bw'),
  FilterPreset(name: 'Hangat', temperature: 0.5, brightness: 0.05, saturation: 0.15),
  FilterPreset(name: 'Dingin', temperature: -0.5, brightness: 0.05, saturation: 0.1),
  FilterPreset(name: 'Dramatis', contrast: 0.4, saturation: -0.2, brightness: -0.05),
  FilterPreset(name: 'Lembut', brightness: 0.1, contrast: -0.15, saturation: -0.1),
  FilterPreset(name: 'Cerah', exposure: 0.2, saturation: 0.25, brilliance: 0.15),
];

// ─── Adjustment Slider Definition ───
class AdjustmentDef {
  final String label;
  final IconData icon;
  final double min;
  final double max;

  const AdjustmentDef({required this.label, required this.icon, this.min = -1.0, this.max = 1.0});
}

const List<AdjustmentDef> kAdjustments = [
  AdjustmentDef(label: 'Kecerahan', icon: Icons.brightness_6),
  AdjustmentDef(label: 'Kontras', icon: Icons.contrast),
  AdjustmentDef(label: 'Saturasi', icon: Icons.palette),
  AdjustmentDef(label: 'Paparan', icon: Icons.exposure),
  AdjustmentDef(label: 'Unggulan', icon: Icons.wb_sunny),
  AdjustmentDef(label: 'Bayangan', icon: Icons.brightness_3),
  AdjustmentDef(label: 'Suhu Warna', icon: Icons.thermostat),
  AdjustmentDef(label: 'Nuansa', icon: Icons.color_lens),
  AdjustmentDef(label: 'Ketajaman', icon: Icons.deblur, min: 0.0),
  AdjustmentDef(label: 'Kecermelangan', icon: Icons.auto_awesome),
  AdjustmentDef(label: 'Vignyet', icon: Icons.vignette, min: 0.0),
];

// ─── Crop Ratio Preset ───
class CropRatioPreset {
  final String label;
  final double? aspectRatio; // null = freeform

  const CropRatioPreset(this.label, this.aspectRatio);
}

const List<CropRatioPreset> kCropRatios = [
  CropRatioPreset('Bebas', null),
  CropRatioPreset('1:1', 1.0),
  CropRatioPreset('4:3', 4.0 / 3.0),
  CropRatioPreset('3:4', 3.0 / 4.0),
  CropRatioPreset('16:9', 16.0 / 9.0),
  CropRatioPreset('9:16', 9.0 / 16.0),
];

// ═══════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════

class PhotoEditScreen extends StatefulWidget {
  final String photoPath;

  const PhotoEditScreen({super.key, required this.photoPath});

  @override
  State<PhotoEditScreen> createState() => _PhotoEditScreenState();
}

class _PhotoEditScreenState extends State<PhotoEditScreen> with TickerProviderStateMixin {
  // ── Current working image bytes (updated after each "apply" operation) ──
  late Uint8List _currentImageBytes;
  Uint8List? _originalImageBytes; // The very first original

  // ── Tab controller ──
  late TabController _tabController;
  int _activeTab = 0; // 0=CropRotate, 1=Sesuaikan, 2=Filter

  // ── Adjustments ──
  final List<double> _adjustmentValues = List.filled(kAdjustments.length, 0.0);
  int _selectedAdjustmentIndex = 0;

  // ── Filter ──
  int _selectedFilterIndex = 0;

  // ── Crop & Rotate ──
  final GlobalKey<ExtendedImageEditorState> _editorKey = GlobalKey<ExtendedImageEditorState>();
  int _rotationCount = 0; // 0, 1, 2, 3 (x90°)
  bool _flipHorizontal = false;
  int _selectedRatioIndex = 0;

  // ── Compare ──
  bool _isComparing = false;

  // ── Dirty tracking ──
  bool _hasUnsavedChanges = false;

  // ── Saving ──
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Auto-apply pending color changes when leaving Sesuaikan or Filter tab
        final fromTab = _tabController.previousIndex;
        if ((fromTab == 1 && _hasAdjustmentChanges) || (fromTab == 2 && _hasFilterChanges)) {
          _applyColorChanges();
        }
      }
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _tabController.index);
      }
    });
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await File(widget.photoPath).readAsBytes();
    setState(() {
      _currentImageBytes = Uint8List.fromList(bytes);
      _originalImageBytes = Uint8List.fromList(bytes);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Check if any adjustment has been changed ──
  bool get _hasAdjustmentChanges => _adjustmentValues.any((v) => v != 0);
  bool get _hasFilterChanges => _selectedFilterIndex != 0;
  bool get _hasCropChanges => _rotationCount != 0 || _flipHorizontal;

  // ── Build combined color matrix from adjustments ──
  List<double> _buildAdjustmentMatrix() {
    return ColorMatrixBuilder.buildCombined(
      brightnessVal: _adjustmentValues[0],
      contrastVal: _adjustmentValues[1],
      saturationVal: _adjustmentValues[2],
      exposureVal: _adjustmentValues[3],
      highlightsVal: _adjustmentValues[4],
      shadowsVal: _adjustmentValues[5],
      temperatureVal: _adjustmentValues[6],
      tintVal: _adjustmentValues[7],
      // sharpness [8] handled separately
      brillianceVal: _adjustmentValues[9],
      // vignette [10] handled separately
    );
  }

  // ── Get current effective color matrix (adjustments OR filter, not both) ──
  List<double>? _getEffectiveMatrix() {
    if (_hasFilterChanges) {
      final preset = kFilterPresets[_selectedFilterIndex];
      final m = preset.toMatrix();
      final isIdentity = m.every((v) => v == ColorMatrixBuilder.identity()[m.indexOf(v)]);
      return isIdentity ? null : m;
    }
    if (_hasAdjustmentChanges) {
      return _buildAdjustmentMatrix();
    }
    return null;
  }

  bool get _hasAnyChanges => _hasAdjustmentChanges || _hasFilterChanges || _hasCropChanges;

  // ═══════════════════════════════════════════════════
  // APPLY CROP/ROTATE (burns changes into _currentImageBytes)
  // ═══════════════════════════════════════════════════
  Future<void> _applyCropRotate() async {
    final state = _editorKey.currentState;
    if (state == null) return;


    final cropRect = state.getCropRect();
    if (cropRect == null) return;

    // Decode original
    final codec = await ui.instantiateImageCodec(_currentImageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Calculate source rect
    final src = Rect.fromLTWH(
      cropRect.left,
      cropRect.top,
      cropRect.width,
      cropRect.height,
    );

    double outputWidth = cropRect.width;
    double outputHeight = cropRect.height;

    // Handle rotation
    final totalRotation = (_rotationCount % 4) * 90.0;
    if (totalRotation == 90 || totalRotation == 270) {
      final temp = outputWidth;
      outputWidth = outputHeight;
      outputHeight = temp;
    }

    canvas.save();

    // Apply transformations
    if (totalRotation != 0) {
      canvas.translate(outputWidth / 2, outputHeight / 2);
      canvas.rotate(totalRotation * math.pi / 180);
      canvas.translate(-cropRect.width / 2, -cropRect.height / 2);
    }

    if (_flipHorizontal) {
      if (totalRotation == 0 || totalRotation == 180) {
        canvas.translate(cropRect.width, 0);
        canvas.scale(-1, 1);
      } else {
        canvas.translate(0, cropRect.height);
        canvas.scale(1, -1);
      }
    }

    canvas.drawImageRect(
      srcImage,
      src,
      Rect.fromLTWH(0, 0, cropRect.width, cropRect.height),
      Paint(),
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final result = await picture.toImage(outputWidth.round(), outputHeight.round());
    final byteData = await result.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      setState(() {
        _currentImageBytes = byteData.buffer.asUint8List();
        _rotationCount = 0;
        _flipHorizontal = false;
        _selectedRatioIndex = 0;
        _hasUnsavedChanges = true;
      });
    }

    srcImage.dispose();
    result.dispose();
  }

  // ═══════════════════════════════════════════════════
  // APPLY ADJUSTMENTS/FILTER (burns color changes into _currentImageBytes)
  // ═══════════════════════════════════════════════════
  Future<void> _applyColorChanges() async {
    final matrix = _getEffectiveMatrix();
    if (matrix == null) return;

    final codec = await ui.instantiateImageCodec(_currentImageBytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..colorFilter = ui.ColorFilter.matrix(matrix);

    canvas.drawImage(srcImage, Offset.zero, paint);

    final picture = recorder.endRecording();
    final result = await picture.toImage(srcImage.width, srcImage.height);
    final byteData = await result.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      setState(() {
        _currentImageBytes = byteData.buffer.asUint8List();
        // Reset adjustment/filter state after burning in
        for (int i = 0; i < _adjustmentValues.length; i++) {
          _adjustmentValues[i] = 0;
        }
        _selectedFilterIndex = 0;
        _hasUnsavedChanges = true;
      });
    }

    srcImage.dispose();
    result.dispose();
  }

  // ═══════════════════════════════════════════════════
  // SAVE TO FILE
  // ═══════════════════════════════════════════════════
  Future<void> _saveImage() async {
    // First apply any pending color changes
    if (_hasAdjustmentChanges || _hasFilterChanges) {
      await _applyColorChanges();
    }

    setState(() => _isSaving = true);

    try {
      final originalFile = File(widget.photoPath);
      final dir = originalFile.parent;
      final fileName = originalFile.uri.pathSegments.last;
      final newFileName = 'edited_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final newFile = File('${dir.path}/$newFileName');
      
      await newFile.writeAsBytes(_currentImageBytes);
      
      try {
        await Gal.putImage(newFile.path);
      } catch (e) {
        debugPrint('Gagal menyimpan ke galeri sistem: $e');
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context, true); // true = image was modified
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  // ═══════════════════════════════════════════════════
  // CANCEL WITH CONFIRMATION
  // ═══════════════════════════════════════════════════
  Future<bool> _confirmDiscard() async {
    if (!_hasAnyChanges && !_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Buang Perubahan?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Semua perubahan yang belum disimpan akan hilang.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buang', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ═══════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_originalImageBytes == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              if (await _confirmDiscard()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          title: const Text('Edit Foto', style: TextStyle(color: Colors.white, fontSize: 18)),
          actions: [
            // Apply button only for Crop tab (adjustments/filters auto-apply on tab switch)
            if (_activeTab == 0 && _hasCropChanges)
              TextButton(
                onPressed: _applyCropRotate,
                child: const Text('Terapkan', style: TextStyle(color: Colors.blueAccent)),
              ),
            // Save button
            TextButton(
              onPressed: (_hasAnyChanges || _hasUnsavedChanges) && !_isSaving ? _saveImage : null,
              child: Text(
                'Simpan',
                style: TextStyle(
                  color: (_hasAnyChanges || _hasUnsavedChanges) ? Colors.greenAccent : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Image Preview ──
            Expanded(child: _buildImagePreview()),
            // ── Tab Bar ──
            Container(
              color: const Color(0xFF1A1A1A),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.crop_rotate, size: 20), text: 'Potong'),
                  Tab(icon: Icon(Icons.tune, size: 20), text: 'Sesuaikan'),
                  Tab(icon: Icon(Icons.filter_vintage, size: 20), text: 'Filter'),
                ],
              ),
            ),
            // ── Tab Content ──
            SizedBox(
              height: 160,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildCropRotateControls(),
                  _buildAdjustControls(),
                  _buildFilterControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // IMAGE PREVIEW
  // ═══════════════════════════════════════════════════
  Widget _buildImagePreview() {
    final matrix = _isComparing ? null : _getEffectiveMatrix();
    final vignetteVal = _isComparing ? 0.0 : _adjustmentValues[10];
    final showOriginal = _isComparing;

    Widget imageWidget;

    if (_activeTab == 0) {
      // Crop mode: use ExtendedImage editor
      imageWidget = ExtendedImage.memory(
        showOriginal ? _originalImageBytes! : _currentImageBytes,
        key: ValueKey('crop_${_currentImageBytes.length}_$showOriginal'),
        fit: BoxFit.contain,
        mode: ExtendedImageMode.editor,
        extendedImageEditorKey: _editorKey,
        initEditorConfigHandler: (state) {
          return EditorConfig(
            maxScale: 8.0,
            cropRectPadding: const EdgeInsets.all(20),
            cropAspectRatio: kCropRatios[_selectedRatioIndex].aspectRatio,
            initCropRectType: InitCropRectType.imageRect,
            editorMaskColorHandler: (context, pointerDown) {
              return Colors.black.withValues(alpha: 0.7);
            },
          );
        },
      );
    } else {
      // Non-crop mode: simple preview
      imageWidget = Image.memory(
        showOriginal ? _originalImageBytes! : _currentImageBytes,
        key: ValueKey('preview_${_currentImageBytes.length}_$showOriginal'),
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }

    // Apply color filter
    if (matrix != null) {
      imageWidget = ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(matrix),
        child: imageWidget,
      );
    }

    return Stack(
      children: [
        // Image
        Center(child: imageWidget),

        // Vignette overlay
        if (vignetteVal > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _VignettePainter(vignetteVal),
              ),
            ),
          ),

        // Compare button
        if (_hasAnyChanges || _hasUnsavedChanges)
          Positioned(
            left: 16,
            bottom: 16,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isComparing = true),
              onTapUp: (_) => setState(() => _isComparing = false),
              onTapCancel: () => setState(() => _isComparing = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isComparing ? Icons.visibility : Icons.visibility_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isComparing ? 'Asli' : 'Bandingkan',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Saving overlay
        if (_isSaving)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Menyimpan...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  // CROP & ROTATE CONTROLS
  // ═══════════════════════════════════════════════════
  Widget _buildCropRotateControls() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCropAction(Icons.rotate_left, 'Putar', () {
                setState(() {
                  _rotationCount = (_rotationCount - 1) % 4;
                });
                _editorKey.currentState?.rotate(degree: -90, animation: true);
              }),
              _buildCropAction(Icons.rotate_right, 'Putar', () {
                setState(() {
                  _rotationCount = (_rotationCount + 1) % 4;
                });
                _editorKey.currentState?.rotate(degree: 90, animation: true);
              }),
              _buildCropAction(Icons.flip, 'Cermin', () {
                setState(() {
                  _flipHorizontal = !_flipHorizontal;
                });
                _editorKey.currentState?.flip();
              }),
              _buildCropAction(Icons.restart_alt, 'Reset', () {
                setState(() {
                  _rotationCount = 0;
                  _flipHorizontal = false;
                  _selectedRatioIndex = 0;
                });
                _editorKey.currentState?.reset();
              }),
            ],
          ),
          const SizedBox(height: 12),
          // Aspect ratio chips
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kCropRatios.length,
              itemBuilder: (context, index) {
                final ratio = kCropRatios[index];
                final isSelected = _selectedRatioIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(ratio.label),
                    selected: isSelected,
                    selectedColor: Colors.white,
                    backgroundColor: const Color(0xFF333333),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedRatioIndex = index);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCropAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ADJUST CONTROLS
  // ═══════════════════════════════════════════════════
  Widget _buildAdjustControls() {
    final adj = kAdjustments[_selectedAdjustmentIndex];
    final value = _adjustmentValues[_selectedAdjustmentIndex];

    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // Vernier Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                // Label + value display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      adj.label,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (value * 100).round().toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Custom vernier ruler
                SizedBox(
                  height: 48,
                  child: _VernierSlider(
                    value: value,
                    min: adj.min,
                    max: adj.max,
                    onChanged: (v) {
                      setState(() => _adjustmentValues[_selectedAdjustmentIndex] = v);
                    },
                    onReset: () {
                      setState(() => _adjustmentValues[_selectedAdjustmentIndex] = 0);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Adjustment selector row
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: kAdjustments.length,
              itemBuilder: (context, index) {
                final item = kAdjustments[index];
                final isSelected = _selectedAdjustmentIndex == index;
                final hasValue = _adjustmentValues[index] != 0;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAdjustmentIndex = index),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.white : (hasValue ? Colors.white24 : Colors.transparent),
                            border: Border.all(
                              color: isSelected ? Colors.white : (hasValue ? Colors.white54 : Colors.white30),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white60,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // FILTER CONTROLS
  // ═══════════════════════════════════════════════════
  Widget _buildFilterControls() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          itemCount: kFilterPresets.length,
          itemBuilder: (context, index) {
            final preset = kFilterPresets[index];
            final isSelected = _selectedFilterIndex == index;
            final matrix = preset.name == 'Asli' ? null : preset.toMatrix();

            Widget thumb = Image.memory(
              _currentImageBytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            );

            if (matrix != null) {
              thumb = ColorFiltered(
                colorFilter: ui.ColorFilter.matrix(matrix),
                child: thumb,
              );
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilterIndex = index;
                  // Reset adjustments when picking a filter
                  if (index != 0) {
                    for (int i = 0; i < _adjustmentValues.length; i++) {
                      _adjustmentValues[i] = 0;
                    }
                  }
                });
              },
              child: Container(
                width: 90,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : Border.all(color: Colors.white24, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: thumb,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.name,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// VERNIER / RULER SLIDER
// ═══════════════════════════════════════════════════
class _VernierSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  const _VernierSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onReset,
  });

  @override
  State<_VernierSlider> createState() => _VernierSliderState();
}

class _VernierSliderState extends State<_VernierSlider> {
  late ScrollController _scrollController;
  bool _isUserScrolling = false;

  // Total ruler width in logical pixels
  static const double _rulerWidth = 2000.0;
  static const double _tickSpacing = 10.0;

  double get _range => widget.max - widget.min;

  double _valueToScrollOffset(double value) {
    final fraction = (value - widget.min) / _range;
    return fraction * _rulerWidth;
  }

  double _scrollOffsetToValue(double offset) {
    final fraction = offset / _rulerWidth;
    return (fraction * _range + widget.min).clamp(widget.min, widget.max);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _valueToScrollOffset(widget.value),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _VernierSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isUserScrolling && oldWidget.value != widget.value) {
      final target = _valueToScrollOffset(widget.value);
      if ((_scrollController.offset - target).abs() > 1) {
        _scrollController.jumpTo(target);
      }
    }
  }

  void _onScroll() {
    if (!_isUserScrolling) return;
    final newValue = _scrollOffsetToValue(_scrollController.offset);
    widget.onChanged(newValue);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onReset,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            _isUserScrolling = true;
          } else if (notification is ScrollEndNotification) {
            _isUserScrolling = false;
          }
          return false;
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ruler track
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Container(
                width: _rulerWidth + MediaQuery.of(context).size.width,
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 2),
                child: CustomPaint(
                  painter: _VernierRulerPainter(
                    min: widget.min,
                    max: widget.max,
                    rulerWidth: _rulerWidth,
                    tickSpacing: _tickSpacing,
                  ),
                ),
              ),
            ),
            // Center indicator (fixed triangle/line)
            IgnorePointer(
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: CustomPaint(
                  painter: _CenterIndicatorPainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VernierRulerPainter extends CustomPainter {
  final double min;
  final double max;
  final double rulerWidth;
  final double tickSpacing;

  _VernierRulerPainter({
    required this.min,
    required this.max,
    required this.rulerWidth,
    required this.tickSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickCount = (rulerWidth / tickSpacing).round();
    final range = max - min;
    final centerFraction = (0 - min) / range; // Where zero is
    final centerX = centerFraction * rulerWidth;

    for (int i = 0; i <= tickCount; i++) {
      final x = i * tickSpacing;
      final isMajor = i % 10 == 0;
      final isMid = i % 5 == 0;

      double tickHeight;
      double tickWidth;
      Color tickColor;

      if (isMajor) {
        tickHeight = 24;
        tickWidth = 1.5;
        tickColor = Colors.white54;
      } else if (isMid) {
        tickHeight = 16;
        tickWidth = 1.0;
        tickColor = Colors.white38;
      } else {
        tickHeight = 10;
        tickWidth = 0.5;
        tickColor = Colors.white24;
      }

      // Highlight the center tick (zero value) with a different color
      final isCenter = (x - centerX).abs() < tickSpacing / 2;
      if (isCenter && isMajor) {
        tickColor = Colors.white;
        tickWidth = 2.0;
      }

      final paint = Paint()
        ..color = tickColor
        ..strokeWidth = tickWidth;

      final top = (size.height - tickHeight) / 2;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + tickHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VernierRulerPainter oldDelegate) => false;
}

class _CenterIndicatorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    // Vertical line
    canvas.drawLine(
      Offset(centerX, 4),
      Offset(centerX, size.height - 4),
      paint,
    );

    // Top triangle
    final trianglePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(centerX - 5, 2)
      ..lineTo(centerX + 5, 2)
      ..lineTo(centerX, 8)
      ..close();
    canvas.drawPath(path, trianglePaint);

    // Bottom triangle
    final bottomPath = Path()
      ..moveTo(centerX - 5, size.height - 2)
      ..lineTo(centerX + 5, size.height - 2)
      ..lineTo(centerX, size.height - 8)
      ..close();
    canvas.drawPath(bottomPath, trianglePaint);
  }

  @override
  bool shouldRepaint(_CenterIndicatorPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════
// VIGNETTE PAINTER
// ═══════════════════════════════════════════════════
class _VignettePainter extends CustomPainter {
  final double intensity; // 0.0 to 1.0

  _VignettePainter(this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    // innerRadius controls the vignette fade start point
    final _ = maxRadius * (1 - intensity * 0.6);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: intensity * 0.8),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_VignettePainter oldDelegate) => oldDelegate.intensity != intensity;
}
