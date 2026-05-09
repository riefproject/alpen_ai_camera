import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import '../widgets/filter_applier.dart';

// Widget Jangka Sorong (Ruler) sederhana untuk Zoom
class ZoomRuler extends StatefulWidget {
  final double min;
  final double max;
  final double initialValue;
  final ValueChanged<double> onChanged;

  const ZoomRuler({
    Key? key,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ZoomRuler> createState() => _ZoomRulerState();
}

class _ZoomRulerState extends State<ZoomRuler> {
  late ScrollController _scrollController;
  final double _itemWidth = 10.0;
  final int _divisions = 100; // Pembagian titik ukur

  @override
  void initState() {
    super.initState();
    // Hitung posisi awal berdasarkan initialValue
    double initialOffset = ((widget.initialValue - widget.min) / (widget.max - widget.min)) * (_divisions * _itemWidth);
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    double offset = _scrollController.offset;
    double maxOffset = _divisions * _itemWidth;
    double percent = (offset / maxOffset).clamp(0.0, 1.0);
    double value = widget.min + (percent * (widget.max - widget.min));
    widget.onChanged(value);
  }

  @override
  void didUpdateWidget(covariant ZoomRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika value dari parent berubah mendadak, kita animasikan scrollnya
    if ((oldWidget.initialValue - widget.initialValue).abs() > 0.1) {
      double targetOffset = ((widget.initialValue - widget.min) / (widget.max - widget.min)) * (_divisions * _itemWidth);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(targetOffset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30, // lebih slim
      child: Stack(
        alignment: Alignment.center,
        children: [
          ListView.builder(
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
          // Indikator tengah
          Container(
            width: 2,
            height: 20,
            color: Colors.yellowAccent,
          ),
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
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isReady = false;
  bool _isCapturing = false;

  FlashMode _flashMode = FlashMode.off;
  String _activeTopMenu = 'none'; 
  String _aspectRatio = '4:3';
  String _hdrMode = 'AUTO';
  int _timer = 0; 
  bool _aiEnabled = true;
  bool _showFilters = false;
  bool _showTopSettings = false; // Panel atas
  String _selectedFilter = 'Asli';
  String _selectedMode = 'FOTO';
  
  double _currentZoom = 1.0;
  double _minAppZoom = 0.5;
  double _maxAppZoom = 10.0;
  double _minHardwareZoom = 1.0;
  double _maxHardwareZoom = 10.0;

  final List<String> _filters = ['Asli', 'Alami', 'Manis', 'Keriangan', 'Kristal'];
  final List<String> _cameraModes = ['MALAM', 'VIDEO', 'FOTO', 'POTRET', '64M'];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _setCamera(_cameras.first);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _setCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _minHardwareZoom = await _controller!.getMinZoomLevel();
      _maxHardwareZoom = await _controller!.getMaxZoomLevel();
      
      // Walau UI bisa diset 0.5 sd 10.0, pas nge-hit hardware akan dilimit aman
      _minAppZoom = 0.5;
      _maxAppZoom = 10.0;
      
      await _controller!.setFlashMode(_flashMode);
      if (mounted) {
        setState(() => _isReady = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  void _toggleCamera() {
    if (_cameras.length > 1) {
      final currentLensDir = _controller!.description.lensDirection;
      final newCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection != currentLensDir,
        orElse: () => _cameras.first,
      );
      setState(() => _isReady = false);
      _setCamera(newCamera);
    }
  }
  
  Future<void> _capturePhoto() async {
    if (_controller == null || !_isReady || _isCapturing) return;
    
    setState(() => _isCapturing = true);
    
    try {
      if (_timer > 0) {
        await Future.delayed(Duration(seconds: _timer));
      }
      
      final XFile photo = await _controller!.takePicture();
      
      // Save to gallery using gal
      await Gal.putImage(photo.path);
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Tersimpan di Galeri!'), duration: Duration(seconds: 2))
         );
      }
      
    } catch (e) {
      debugPrint('Gagal memproses foto: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _setFlashMode(FlashMode mode) async {
    if (_controller == null) return;
    try {
      await _controller!.setFlashMode(mode);
      setState(() {
        _flashMode = mode;
        _activeTopMenu = 'none';
      });
    } catch (e) {}
  }
  
  void _setZoom(double zoom) {
    if (_controller == null) return;
    final targetUIZoom = zoom.clamp(_minAppZoom, _maxAppZoom);
    // Safe clamp for actual camera sensor
    final targetHardZoom = targetUIZoom.clamp(_minHardwareZoom, _maxHardwareZoom);
    try {
      _controller!.setZoomLevel(targetHardZoom);
    } catch (_) {}
    setState(() {
      _currentZoom = targetUIZoom;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
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
              const Text('Pengatur Waktu', style: TextStyle(color: Colors.white, fontSize: 14)),
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
              const Text('Pengaturan', style: TextStyle(color: Colors.white, fontSize: 14)),
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
                width: 40, height: 4,
                decoration: const BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.all(Radius.circular(4))),
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
        child: Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 20),
      ),
    );
  }

  Widget _buildRatioIcon(String ratio, {bool isSelected = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.crop_free, color: isSelected ? Colors.black : Colors.white, size: 28),
        Text(ratio, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
          const Text('Flash', style: TextStyle(color: Colors.white, fontSize: 14)),
          _buildFlashOption(FlashMode.off, Icons.flash_off),
          _buildFlashOption(FlashMode.always, Icons.flash_on),
          _buildFlashOption(FlashMode.auto, Icons.flash_auto),
          _buildFlashOption(FlashMode.torch, Icons.highlight),
        ],
      );
    } else if (_activeTopMenu == 'hdr') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text('HDR', style: TextStyle(color: Colors.white, fontSize: 14)),
          _buildTextOption('hdr', 'OFF', _hdrMode == 'OFF'),
          _buildTextOption('hdr', 'ON', _hdrMode == 'ON'),
          _buildTextOption('hdr', 'AUTO', _hdrMode == 'AUTO'),
        ],
      );
    } else if (_activeTopMenu == 'ratio') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text('Rasio aspek', style: TextStyle(color: Colors.white, fontSize: 14)),
          _buildRatioOption('1:1', _aspectRatio == '1:1'),
          _buildRatioOption('4:3', _aspectRatio == '4:3'),
          _buildRatioOption('16:9', _aspectRatio == '16:9'),
          _buildRatioOption('Full', _aspectRatio == 'Full'),
        ],
      );
    }

    IconData getFlashIcon() {
      switch (_flashMode) {
        case FlashMode.off: return Icons.flash_off;
        case FlashMode.always: return Icons.flash_on;
        case FlashMode.auto: return Icons.flash_auto;
        case FlashMode.torch: return Icons.highlight;
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
              const Text('HDR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              if (_hdrMode != 'ON')
                Text(_hdrMode, style: const TextStyle(color: Colors.white70, fontSize: 9)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _aiEnabled = !_aiEnabled),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              'AI',
              style: TextStyle(
                color: _aiEnabled ? Colors.yellowAccent : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _activeTopMenu = 'ratio'),
          child: _buildRatioIcon(_aspectRatio == 'Full' ? 'Full' : _aspectRatio),
        ),
        GestureDetector(
          onTap: _toggleTopSettings,
          child: Icon(_showTopSettings ? Icons.close : Icons.more_vert, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  Widget _buildFlashOption(FlashMode mode, IconData icon) {
    bool isSelected = _flashMode == mode;
    return GestureDetector(
      onTap: () => _setFlashMode(mode),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFFD4E157) : Colors.white24,
        ),
        child: Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 18),
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
          style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
              Text('${_currentZoom.toStringAsFixed(1)}X', style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: ZoomRuler(
                  min: _minAppZoom,
                  max: _maxAppZoom,
                  initialValue: _currentZoom,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _setZoom(0.5),
                      child: const Icon(Icons.park, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => _setZoom(1.0),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('${_currentZoom.toStringAsFixed(1)}X', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => _setZoom(2.0),
                      child: const Icon(Icons.nature, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showFilters = true),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
                  child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCarousel() {
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
                      border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        width: 60, height: 60,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.previewSize?.height ?? 1,
                            height: _controller!.value.previewSize?.width ?? 1,
                            child: FilterApplier(
                              filterName: filter,
                              child: CameraPreview(_controller!),
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    switch(_aspectRatio) {
      case '1:1': return 1.0;
      case '16:9': return 9 / 16;
      case 'Full':
      case '4:3':
      default:
         return 3 / 4;
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Percantik', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Filter', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _cameraModes.length,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemBuilder: (context, index) {
                    final mode = _cameraModes[index];
                    final isSelected = _selectedMode == mode;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMode = mode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: Container(
                          padding: isSelected ? const EdgeInsets.symmetric(horizontal: 14, vertical: 4) : null,
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                )
                              : null,
                          child: Text(
                            mode,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        const SizedBox(height: 20),
        
        // Tombol Kamera Bawah
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tombol Galeri
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[900],
                  border: Border.all(color: Colors.white30, width: 1),
                ),
                child: const Icon(Icons.photo, color: Colors.white, size: 24),
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
                      width: _isCapturing ? 70 : 80,
                      height: _isCapturing ? 70 : 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: _isCapturing ? 56 : 66,
                          height: _isCapturing ? 56 : 66,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing ? Colors.grey : Colors.white,
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
                    color: Colors.white.withOpacity(0.15),
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
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    Widget cameraContent = FilterApplier(
      filterName: _selectedFilter,
      child: CameraPreview(_controller!),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _aspectRatio == 'Full'
            ? Stack(
                children: [
                  // Full Screen Camera Feed
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize?.height ?? 1,
                        height: _controller!.value.previewSize?.width ?? 1,
                        child: cameraContent,
                      ),
                    ),
                  ),
                  // Overlays on top of Full Screen Feed
                  Column(
                    children: [
                      Container(
                        color: Colors.black.withOpacity(0.3),
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: _buildTopBarMenu(),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_showFilters) setState(() => _showFilters = false);
                            if (_activeTopMenu != 'none') setState(() => _activeTopMenu = 'none');
                            if (_showTopSettings) setState(() => _showTopSettings = false);
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(child: _buildGridLines()),
                              Positioned.fill(child: _buildGridLinesVertical()),
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: _showFilters ? _buildFilterCarousel() : _buildZoomAndWandOverlay(),
                              ),
                              if (_showTopSettings)
                                Positioned(
                                  top: 0, left: 0, right: 0,
                                  child: _buildTopSettingsPanel(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.3),
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
                      onTap: () {
                        if (_showFilters) setState(() => _showFilters = false);
                        if (_activeTopMenu != 'none') setState(() => _activeTopMenu = 'none');
                        if (_showTopSettings) setState(() => _showTopSettings = false);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            color: Colors.black,
                            width: double.infinity,
                            height: double.infinity,
                            child: Center(
                              // Mengisi Full Width untuk 16:9 
                              child: _aspectRatio == '16:9'
                                  ? SizedBox(
                                      width: double.infinity,
                                      height: MediaQuery.of(context).size.width * 16 / 9,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _controller!.value.previewSize?.height ?? 1,
                                          height: _controller!.value.previewSize?.width ?? 1,
                                          child: cameraContent,
                                        ),
                                      ),
                                    )
                                  : AspectRatio(
                                      aspectRatio: _getAspectRatio(),
                                      child: ClipRect(
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: _controller!.value.previewSize?.height ?? 1,
                                            height: _controller!.value.previewSize?.width ?? 1,
                                            child: cameraContent,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned.fill(child: _buildGridLines()),
                          Positioned.fill(child: _buildGridLinesVertical()),
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: _showFilters ? _buildFilterCarousel() : _buildZoomAndWandOverlay(),
                          ),
                          if (_showTopSettings)
                            Positioned(
                              top: 0, left: 0, right: 0,
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
      ),
    );
  }
}
