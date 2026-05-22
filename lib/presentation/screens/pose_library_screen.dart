import 'dart:io';

import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/presentation/controllers/pose_workflow_controller.dart';
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
  PoseTemplate? _lastUploadedTemplate;

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
      _uploadMessage = 'Memproses gambar menjadi pose...';
    });

    await widget.controller.buildTemplateFromUpload(image.path);
    if (!mounted) {
      return;
    }

    setState(() {
      _isUploading = false;
      _uploadMessage =
          widget.controller.errorMessage ?? 'Pose berhasil ditambahkan';
      _lastUploadedTemplate = widget.controller.errorMessage == null
          ? widget.controller.selectedTemplate
          : null;
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
                      if (_lastUploadedTemplate?.sourceImagePath != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: _UploadedPosePreview(
                            template: _lastUploadedTemplate!,
                          ),
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
  });

  final PoseTemplate template;
  final bool isSelected;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUse,
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

class _UploadedPosePreview extends StatelessWidget {
  const _UploadedPosePreview({required this.template});

  final PoseTemplate template;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.lightGreenAccent.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              'Preview ekstraksi pose',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _PoseTemplatePreviewSurface(
                  template: template,
                  isSelected: true,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseTemplatePreviewSurface extends StatelessWidget {
  const _PoseTemplatePreviewSurface({
    required this.template,
    required this.isSelected,
    this.fit = BoxFit.fill,
  });

  final PoseTemplate template;
  final bool isSelected;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final sourceImagePath = template.sourceImagePath;
    final imageFile = sourceImagePath == null ? null : File(sourceImagePath);
    final hasImage = imageFile != null && imageFile.existsSync();
    final overlayColor = isSelected ? Colors.lightGreenAccent : Colors.white;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.file(imageFile, fit: fit, alignment: Alignment.center)
        else
          const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
        Container(color: Colors.black.withValues(alpha: hasImage ? 0.18 : 0)),
        Padding(
          padding: EdgeInsets.all(hasImage ? 0 : 4),
          child: PoseOutlinePreview(template: template, color: overlayColor),
        ),
      ],
    );
  }
}
