import 'dart:io';
import 'dart:ui' as ui;

import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/presentation/controllers/pose_workflow_controller.dart';
import 'package:alpen_ai_camera/presentation/widgets/pose_ghost_overlay.dart';
import 'package:flutter/material.dart';

class PoseViewerScreen extends StatefulWidget {
  const PoseViewerScreen({
    required this.template,
    required this.controller,
    super.key,
  });

  final PoseTemplate template;
  final PoseWorkflowController controller;

  @override
  State<PoseViewerScreen> createState() => _PoseViewerScreenState();
}

class _PoseViewerScreenState extends State<PoseViewerScreen> {
  bool _showOverlay = true;
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(template.name),
        actions: [
          IconButton(
            icon: Icon(
              _showOverlay ? Icons.visibility : Icons.visibility_off,
              color: _showOverlay ? Colors.lightGreenAccent : Colors.white54,
            ),
            tooltip: 'Toggle overlay',
            onPressed: () => setState(() => _showOverlay = !_showOverlay),
          ),
        ],
      ),
      body: SafeArea(
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
                    )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFF1B1B1B)),
                    ),
                  Container(
                    color: Colors.black.withValues(alpha: hasImage ? 0.25 : 0),
                  ),
                  if (_showOverlay)
                    PoseOutlinePreview(
                      template: template,
                      color: Colors.lightGreenAccent,
                      previewSize: _imageSize,
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
                      icon: const Icon(Icons.arrow_back, size: 20),
                      label: const Text('Kembali'),
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
    );
  }
}
