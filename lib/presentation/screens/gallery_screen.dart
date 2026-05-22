import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'photo_edit_screen.dart';

// Run file listing in isolate so main thread is never blocked
Future<List<String>> _listPhotoPaths(String dirPath) async {
  final dir = Directory(dirPath);
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
      .toList();
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return files.map((f) => f.path).toList();
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<String> _photoPaths = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Run on isolate to avoid blocking UI during file system scan
      final paths = await compute(_listPhotoPaths, dir.path);
      if (mounted) {
        setState(() {
          _photoPaths = paths;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat foto: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  Widget _buildGrid(List<String> paths) {
    if (paths.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, color: Colors.white30, size: 64),
            SizedBox(height: 16),
            Text('Belum ada foto', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    
    final tileSize = (MediaQuery.of(context).size.width / 3).ceil();
    
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: paths.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        final path = paths[index];
        final isSelected = _selectedPaths.contains(path);
        
        return GestureDetector(
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedPaths.add(path);
              });
            }
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(path);
            } else {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      FullScreenImageView(photoPaths: paths, initialIndex: index),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              ).then((_) {
                setState(() {});
              });
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.all(isSelected ? 8.0 : 0.0),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: tileSize,
                  gaplessPlayback: true,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) return child;
                    return Container(color: const Color(0xFF1A1A1A));
                  },
                ),
              ),
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.check_circle, color: Colors.blueAccent, size: 24),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _batchFavorite() {
    final box = Hive.box<bool>('favorites_box');
    for (final path in _selectedPaths) {
      box.put(path, true);
    }
    setState(() {
      _isSelectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _batchDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Hapus Foto', style: TextStyle(color: Colors.white)),
          content: Text('Anda yakin ingin menghapus ${_selectedPaths.length} foto secara permanen?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // close confirm dialog
                
                // Show progress dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF2C2C2C),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text('Menghapus ${_selectedPaths.length} foto...', style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  },
                );

                final box = Hive.box<bool>('favorites_box');
                for (final path in _selectedPaths) {
                  final file = File(path);
                  if (await file.exists()) {
                    await file.delete();
                  }
                  box.delete(path);
                  // Yield to UI thread to keep progress spinner animating smoothly
                  await Future.delayed(const Duration(milliseconds: 10));
                }
                
                if (!mounted) return;
                Navigator.pop(context); // close progress dialog
                setState(() {
                  _isSelectionMode = false;
                  _selectedPaths.clear();
                });
                _loadPhotos(); // refresh list
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: const Color(0xFF1E1E1E),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedPaths.clear();
                    });
                  },
                ),
                title: Text('${_selectedPaths.length} Terpilih', style: const TextStyle(color: Colors.white)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.select_all, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        // We need a way to know WHICH tab is currently active to select all photos in it.
                        // For simplicity, we just select all _photoPaths.
                        if (_selectedPaths.length == _photoPaths.length) {
                          _selectedPaths.clear();
                          _isSelectionMode = false;
                        } else {
                          _selectedPaths.addAll(_photoPaths);
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.greenAccent),
                    onPressed: _batchFavorite,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: _batchDelete,
                  ),
                ],
                bottom: const PreferredSize(preferredSize: Size.fromHeight(48), child: SizedBox()), // Keep tab space
              )
            : AppBar(
                title: const Text('Galeri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                surfaceTintColor: Colors.transparent,
                bottom: const TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  tabs: [
                    Tab(text: 'Semua'),
                    Tab(text: 'Favorit'),
                  ],
                ),
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ValueListenableBuilder(
                valueListenable: Hive.box<bool>('favorites_box').listenable(),
                builder: (context, Box<bool> box, _) {
                  final favoritePaths = _photoPaths.where((p) => box.get(p, defaultValue: false) == true).toList();
                  return TabBarView(
                    children: [
                      _buildGrid(_photoPaths),
                      _buildGrid(favoritePaths),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class FullScreenImageView extends StatefulWidget {
  final List<String> photoPaths;
  final int initialIndex;

  const FullScreenImageView({super.key, required this.photoPaths, required this.initialIndex});

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isHudVisible = true;
  late Box<bool> _favoritesBox;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _favoritesBox = Hive.box<bool>('favorites_box');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}.${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  bool _isSheetOpen = false;

  void _showDetails(String path) async {
    if (_isSheetOpen) return;
    
    final file = File(path);
    if (!file.existsSync()) return;
    
    final stat = await file.stat();
    final decodedImage = await decodeImageFromList(await file.readAsBytes());
    final width = decodedImage.width;
    final height = decodedImage.height;
    
    if (!mounted) return;

    _isSheetOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('Rincian', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildDetailRow(Icons.image, 'Nama', path.split('/').last),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.access_time, 'Waktu', '${_formatDate(stat.modified)} ${_formatTime(stat.modified)}'),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.aspect_ratio, 'Dimensi', '$width x $height'),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.sd_storage, 'Ukuran', _formatSize(stat.size)),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.folder_open, 'Lokasi', path),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _isSheetOpen = false;
    });
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Hapus Foto?', style: TextStyle(color: Colors.white)),
        content: const Text('Foto ini akan dihapus secara permanen dari perangkat.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              File(path).deleteSync();
              _favoritesBox.delete(path);
              Navigator.pop(context); // Close full screen view
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoPaths.isEmpty || _currentIndex >= widget.photoPaths.length) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final currentPath = widget.photoPaths[_currentIndex];
    final file = File(currentPath);
    final dt = file.existsSync() ? file.lastModifiedSync() : DateTime.now();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image PageView
          GestureDetector(
            onTap: () {
              setState(() => _isHudVisible = !_isHudVisible);
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photoPaths.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Center(
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Image.file(
                      File(widget.photoPaths[index]),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                );
              },
            ),
          ),

          // Top HUD
          AnimatedOpacity(
            opacity: _isHudVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.topCenter,
              child: IgnorePointer(
                ignoring: !_isHudVisible,
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 8, right: 16, bottom: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(dt), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(_formatTime(dt), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom HUD
          AnimatedOpacity(
            opacity: _isHudVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                ignoring: !_isHudVisible,
                child: Container(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildHudAction(
                        icon: Icons.share,
                        label: 'Kirim',
                        onTap: () async {
                          await Share.shareXFiles([XFile(currentPath)], text: 'Dikirim dari Alpen AI Camera');
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: _favoritesBox.listenable(keys: [currentPath]),
                        builder: (context, box, _) {
                          final isFavorite = box.get(currentPath, defaultValue: false) == true;
                          return _buildHudAction(
                            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                            label: 'Favorit',
                            color: isFavorite ? Colors.greenAccent : Colors.white,
                            onTap: () {
                              if (isFavorite) {
                                box.delete(currentPath);
                              } else {
                                box.put(currentPath, true);
                              }
                            },
                          );
                        },
                      ),
                      _buildHudAction(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoEditScreen(photoPath: currentPath)));
                        },
                      ),
                      _buildHudAction(
                        icon: Icons.delete_outline,
                        label: 'Hapus',
                        onTap: () => _confirmDelete(currentPath),
                      ),
                      _buildHudAction(
                        icon: Icons.more_vert,
                        label: 'Selengkapnya',
                        onTap: () => _showDetails(currentPath),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudAction({required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.white}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
