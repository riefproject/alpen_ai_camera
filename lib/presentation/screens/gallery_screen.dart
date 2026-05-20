import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final tileSize = (MediaQuery.of(context).size.width / 3).ceil();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Galeri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _photoPaths.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined, color: Colors.white30, size: 64),
                      SizedBox(height: 16),
                      Text('Belum ada foto', style: TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: _photoPaths.length,
                  // addAutomaticKeepAlives: false to avoid keeping every cell in memory
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  itemBuilder: (context, index) {
                    final path = _photoPaths[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                FullScreenImageView(photoPath: path),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        // Decode at thumbnail size only — much faster, much less memory
                        cacheWidth: tileSize,
                        cacheHeight: tileSize,
                        gaplessPlayback: true,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) return child;
                          return Container(color: const Color(0xFF1A1A1A));
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class FullScreenImageView extends StatelessWidget {
  final String photoPath;

  const FullScreenImageView({super.key, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,
          maxScale: 5.0,
          child: Image.file(
            File(photoPath),
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
