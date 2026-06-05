import 'dart:io';
import 'dart:ui' as ui;

import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/presentation/controllers/pose_workflow_controller.dart';
import 'package:alpen_ai_camera/presentation/widgets/pose_ghost_overlay.dart';
import 'package:alpen_ai_camera/presentation/widgets/scanning_overlay.dart';
import 'package:flutter/material.dart';

class PosePreviewScreen extends StatefulWidget {
  const PosePreviewScreen({
    required this.template,
    required this.controller,
    super.key,
  });

  final PoseTemplate template;
  final PoseWorkflowController controller;

  @override
  State<PosePreviewScreen> createState() => _PosePreviewScreenState();
}

class _PosePreviewScreenState extends State<PosePreviewScreen> {
  bool _isScanning = true;
  bool _showContent = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final path = widget.template.sourceImagePath;
    if (path == null) return;
    if (widget.template.sourceImageWidth != null &&
        widget.template.sourceImageHeight != null) {
      return;
    }
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      if (!mounted) {
        image.dispose();
        codec.dispose();
        return;
      }
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
      image.dispose();
      codec.dispose();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final sourceImagePath = template.sourceImagePath;
    final imageFile = sourceImagePath == null ? null : File(sourceImagePath);
    final hasImage = imageFile != null && imageFile.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_showContent)
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasImage)
                          Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        Container(
                          color: Colors.black.withValues(alpha: hasImage ? 0.35 : 0),
                        ),
                        PoseOutlinePreview(
                          template: template,
                          color: Colors.lightGreenAccent,
                          previewSize: _imageSize,
                        ),
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Pose berhasil diekstrak',
                                style: TextStyle(
                                  color: Colors.lightGreenAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              widget.controller.selectTemplate(template);
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.lightGreenAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 20),
                            label: const Text('Gunakan Pose'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_isScanning)
            ScanningOverlay(
              scanColor: Colors.lightGreenAccent,
              onScanComplete: () {
                if (!mounted) return;
                setState(() {
                  _isScanning = false;
                  _showContent = true;
                });
              },
              child: Container(
                color: Colors.black,
                child: hasImage
                    ? Center(
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}
