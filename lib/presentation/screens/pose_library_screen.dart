import 'dart:io';
import 'dart:ui' as ui;

import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/presentation/controllers/pose_workflow_controller.dart';
import 'package:alpen_ai_camera/presentation/screens/pose_preview_screen.dart';
import 'package:alpen_ai_camera/presentation/screens/pose_viewer_screen.dart';
import 'package:alpen_ai_camera/presentation/widgets/pose_ghost_overlay.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PoseLibraryScreen extends StatefulWidget {
  const PoseLibraryScreen({required this.controller, super.key});

  final PoseWorkflowController controller;

  @override
  State<PoseLibraryScreen> createState() => _PoseLibraryScreenState();
}

class _PoseLibraryScreenState extends State<PoseLibraryScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true;
  bool _isUploading = false;
  String? _uploadMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    await widget.controller.refreshTemplates();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _uploadPose() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadMessage = 'Memproses gambar...';
    });

    await widget.controller.buildTemplateFromUpload(image.path);
    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
      if (widget.controller.errorMessage != null) {
        _uploadMessage = widget.controller.errorMessage;
      } else {
        _uploadMessage = 'Pose berhasil';
        final template = widget.controller.selectedTemplate;
        if (template != null) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => PosePreviewScreen(
                template: template,
                controller: widget.controller,
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _usePose(PoseTemplate template) async {
    await widget.controller.selectTemplate(template);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final templates = widget.controller.templates;
        final selected = widget.controller.selectedTemplate;

        return Scaffold(
          backgroundColor: const Color(0xFF101010),
          appBar: AppBar(
            backgroundColor: const Color(0xFF101010),
            foregroundColor: Colors.white,
            title: const Text('Pose Library'),
            actions: [
              Row(
                children: [
                  const Text(
                    'Auto',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Switch(
                    value: widget.controller.autoCaptureEnabled,
                    activeThumbColor: Colors.lightGreenAccent,
                    onChanged: widget.controller.setAutoCaptureEnabled,
                  ),
                ],
              ),
            ],
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: _buildUploadCard(),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                          itemCount: templates.length,
                          itemBuilder: (context, index) {
                            final template = templates[index];
                            return _PoseTemplateCard(
                              template: template,
                              isSelected:
                                  selected?.templateId == template.templateId,
                              onUse: () => _usePose(template),
                              onTapViewer: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) => PoseViewerScreen(
                                      template: template,
                                      controller: widget.controller,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: _isUploading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _uploadMessage ?? 'Upload foto pose',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    _uploadMessage != null &&
                        !_uploadMessage!.contains('berhasil') &&
                        !_uploadMessage!.contains('Memproses')
                    ? Colors.orangeAccent
                    : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isUploading ? null : _uploadPose,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Pilih'),
          ),
        ],
      ),
    );
  }
}

class _PoseTemplateCard extends StatelessWidget {
  const _PoseTemplateCard({
    required this.template,
    required this.isSelected,
    required this.onUse,
    this.onTapViewer,
  });

  final PoseTemplate template;
  final bool isSelected;
  final VoidCallback onUse;
  final VoidCallback? onTapViewer;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapViewer ?? onUse,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.lightGreenAccent : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: _PoseTemplatePreviewSurface(
                      template: template,
                      isSelected: isSelected,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.lightGreenAccent,
                      size: 18,
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

class _PoseTemplatePreviewSurface extends StatefulWidget {
  const _PoseTemplatePreviewSurface({
    required this.template,
    required this.isSelected,
  });

  final PoseTemplate template;
  final bool isSelected;

  @override
  State<_PoseTemplatePreviewSurface> createState() =>
      _PoseTemplatePreviewSurfaceState();
}

class _PoseTemplatePreviewSurfaceState
    extends State<_PoseTemplatePreviewSurface> {
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
    final sourceImagePath = widget.template.sourceImagePath;
    final imageFile = sourceImagePath == null ? null : File(sourceImagePath);
    final hasImage = imageFile != null && imageFile.existsSync();
    final overlayColor = widget.isSelected
        ? Colors.lightGreenAccent
        : Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.file(imageFile, fit: BoxFit.fill, alignment: Alignment.center)
        else
          const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
        Container(color: Colors.black.withValues(alpha: hasImage ? 0.18 : 0)),
        Padding(
          padding: EdgeInsets.all(hasImage ? 0 : 4),
          child: PoseOutlinePreview(
            template: widget.template,
            color: overlayColor,
            previewSize: _imageSize,
          ),
        ),
      ],
    );
  }
}
