import 'dart:async';
import 'dart:io';

import 'package:alpen_ai_camera/data/datasources/remote/supabase_public_pose_datasource.dart';
import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:alpen_ai_camera/data/repositories_impl/public_pose_repository_impl.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';
import 'package:alpen_ai_camera/main.dart';
import 'package:alpen_ai_camera/presentation/controllers/pose_workflow_controller.dart';
import 'package:alpen_ai_camera/presentation/controllers/public_pose_controller.dart';
import 'package:alpen_ai_camera/presentation/screens/login_screen.dart';
import 'package:alpen_ai_camera/presentation/widgets/pose_ghost_overlay.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PoseManageScreen extends StatefulWidget {
  const PoseManageScreen({
    required this.template,
    required this.controller,
    super.key,
  });

  final PoseTemplate template;
  final PoseWorkflowController controller;

  @override
  State<PoseManageScreen> createState() => _PoseManageScreenState();
}

class _PoseManageScreenState extends State<PoseManageScreen> {
  late TextEditingController _nameController;
  late final PublicPoseController _publicPoseController;
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploadingPublic = false;
  bool _isAlreadyUploaded = false;
  String _alreadyUploadedLabel = '';

  @override
  void initState() {
    super.initState();
    _isDefault = widget.template.templateId.startsWith('default-');
    _nameController = TextEditingController(text: widget.template.name);
    _publicPoseController = PublicPoseController(
      repository: PublicPoseRepositoryImpl(
        dataSource: SupabasePublicPoseDataSourceImpl(
          client: Supabase.instance.client,
        ),
      ),
    );
    _checkUploadStatus();
  }

  Future<void> _checkUploadStatus() async {
    if (_isDefault) {
      setState(() {
        _isAlreadyUploaded = true;
        _alreadyUploadedLabel = 'Pose bawaan tidak dapat diunggah';
      });
      return;
    }

    if (widget.template.templateId.startsWith('public-')) {
      setState(() {
        _isAlreadyUploaded = true;
        _alreadyUploadedLabel = 'Berasal dari publik';
      });
      return;
    }

    final box = Hive.box<String>('uploaded_poses');
    if (box.containsKey(widget.template.templateId)) {
      setState(() {
        _isAlreadyUploaded = true;
        _alreadyUploadedLabel = 'Sudah diunggah';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || newName == widget.template.name) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.controller.renameTemplate(widget.template.templateId, newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama pose berhasil diubah'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah nama: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      await widget.controller.toggleFavorite(widget.template.templateId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah favorit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Hapus Pose', style: TextStyle(color: Colors.white)),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${widget.template.name}"? Tindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await widget.controller.deleteTemplate(widget.template.templateId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus pose: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadToPublic() async {
    if (!authController.isLoggedIn) {
      final loggedIn = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (context) => const LoginScreen(),
        ),
      );
      if (loggedIn != true || !mounted) return;
    }

    if (!mounted) return;

    setState(() => _isUploadingPublic = true);

    try {
      final templateData = PoseTemplateModel.fromEntity(widget.template).toJson();
      final publicPose = await _publicPoseController.uploadPose(
        title: widget.template.name,
        description: '',
        templateData: templateData,
        sourceImagePath: widget.template.sourceImagePath,
      );

      final uploadedBox = Hive.box<String>('uploaded_poses');
      await uploadedBox.put(widget.template.templateId, publicPose.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pose berhasil diunggah ke publik!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunggah: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPublic = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: const Text('Kelola Pose'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreview(),
              const SizedBox(height: 24),
              _buildNameField(),
              const SizedBox(height: 16),
              _buildFavoriteButton(),
              const SizedBox(height: 16),
              _buildUploadPublicButton(),
              if (!_isDefault) ...[
                const SizedBox(height: 16),
                _buildDeleteButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              widget.template.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _PoseTemplatePreviewSurface(template: widget.template),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nama Pose',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                enabled: !_isDefault,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1B1B1B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  hintText: 'Masukkan nama pose',
                  hintStyle: const TextStyle(color: Colors.white38),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _isDefault || _isSaving ? null : _saveName,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
        if (_isDefault)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Nama pose bawaan tidak dapat diubah',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildFavoriteButton() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final currentTemplate = _findCurrentTemplate();
        final isFavorite = currentTemplate?.isFavorite ?? widget.template.isFavorite;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? const Color(0xFFFFD700) : Colors.white70,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFavorite ? 'Pose Favorit' : 'Tandai sebagai Favorit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: isFavorite,
                activeThumbColor: const Color(0xFFFFD700),
                onChanged: (_) => _toggleFavorite(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadPublicButton() {
    if (_isAlreadyUploaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_done,
              color: Colors.green,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _alreadyUploadedLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 20,
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: _isUploadingPublic ? null : _uploadToPublic,
      icon: _isUploadingPublic
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.public),
      label: Text(_isUploadingPublic ? 'Mengunggah...' : 'Unggah ke Publik'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return FilledButton.icon(
      onPressed: _isDeleting ? null : _deletePose,
      icon: _isDeleting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.delete_outline),
      label: Text(_isDeleting ? 'Menghapus...' : 'Hapus Pose'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  PoseTemplate? _findCurrentTemplate() {
    for (final t in widget.controller.templates) {
      if (t.templateId == widget.template.templateId) {
        return t;
      }
    }
    return null;
  }
}

class _PoseTemplatePreviewSurface extends StatelessWidget {
  const _PoseTemplatePreviewSurface({required this.template});

  final PoseTemplate template;

  @override
  Widget build(BuildContext context) {
    final sourceImagePath = template.sourceImagePath;
    final imageFile = sourceImagePath == null ? null : File(sourceImagePath);
    final hasImage = imageFile != null && imageFile.existsSync();

    if (!hasImage) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
          Padding(
            padding: const EdgeInsets.all(4),
            child: PoseOutlinePreview(template: template, color: Colors.white),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<ImageSize>(
          future: _getImageSize(sourceImagePath!),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.expand();
            }

            final imageSize = snapshot.data!;
            final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
            final fitted = _applyBoxFit(imageSize, containerSize);

            return SizedBox.fromSize(
              size: containerSize,
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: fitted.outputRect,
                    child: ClipRect(
                      child: Image.file(
                        File(sourceImagePath),
                        fit: BoxFit.fill,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.18)),
                  Positioned.fromRect(
                    rect: fitted.outputRect,
                    child: PoseOutlinePreview(
                      template: template,
                      color: Colors.white,
                      previewSize: fitted.outputRect.size,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<ImageSize> _getImageSize(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      return ImageSize(1, 1);
    }
    final completer = Completer<ImageSize>();
    FileImage(file).resolve(ImageConfiguration.empty).addListener(
      ImageStreamListener((info, _) {
        completer.complete(ImageSize(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );
    return completer.future;
  }

  FittedBoxResult _applyBoxFit(
    ImageSize imageSize,
    Size containerSize,
  ) {
    final imageRatio = imageSize.width / imageSize.height;
    final containerRatio = containerSize.width / containerSize.height;
    double outputWidth, outputHeight;

    if (imageRatio > containerRatio) {
      outputWidth = containerSize.width;
      outputHeight = containerSize.width / imageRatio;
    } else {
      outputHeight = containerSize.height;
      outputWidth = containerSize.height * imageRatio;
    }

    final dx = (containerSize.width - outputWidth) / 2;
    final dy = (containerSize.height - outputHeight) / 2;

    return FittedBoxResult(
      outputRect: Rect.fromLTWH(dx, dy, outputWidth, outputHeight),
    );
  }
}

class ImageSize {
  final double width;
  final double height;
  ImageSize(this.width, this.height);
}

class FittedBoxResult {
  final Rect outputRect;
  FittedBoxResult({required this.outputRect});
}
