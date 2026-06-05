import 'dart:async';

import 'package:alpen_ai_camera/data/datasources/local/pose_template_local_datasource.dart';
import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:alpen_ai_camera/domain/entities/public_pose.dart';
import 'package:alpen_ai_camera/presentation/widgets/pose_ghost_overlay.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicPoseDetailScreen extends StatefulWidget {
  const PublicPoseDetailScreen({required this.pose, super.key});

  final PublicPose pose;

  @override
  State<PublicPoseDetailScreen> createState() => _PublicPoseDetailScreenState();
}

class _PublicPoseDetailScreenState extends State<PublicPoseDetailScreen> {
  bool _isDownloading = false;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _checkDownloaded();
  }

  Future<void> _checkDownloaded() async {
    final dataSource = HivePoseTemplateLocalDataSource();
    final downloaded = await dataSource.exists('public-${widget.pose.id}');
    if (mounted) {
      setState(() => _isDownloaded = downloaded);
    }
  }

  Future<void> _downloadPose() async {
    setState(() => _isDownloading = true);

    try {
      await Supabase.instance.client.rpc(
        'increment_download_count',
        params: {'pose_id': widget.pose.id},
      );

      final templateModel = PoseTemplateModel(
        id: 'public-${widget.pose.id}',
        name: widget.pose.title,
        landmarks: PoseTemplateModel.fromEntity(widget.pose.template).landmarks,
        outlinePoints: widget.pose.template.outlinePoints,
        sourceImagePath: widget.pose.sourceImageUrl,
        thumbnailPath: null,
      );

      final dataSource = HivePoseTemplateLocalDataSource();
      await dataSource.saveTemplate(templateModel);

      setState(() => _isDownloaded = true);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pose berhasil diunduh ke library!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pose = widget.pose;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: Text(pose.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreview(),
              const SizedBox(height: 20),
              Text(
                pose.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pose.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  pose.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.download, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    '${pose.downloadCount} unduhan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(pose.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isDownloading || _isDownloaded ? null : _downloadPose,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isDownloaded ? Icons.check : Icons.download),
                label: Text(_isDownloaded ? 'Telah Diunduh' : 'Unduh Pose'),
                style: FilledButton.styleFrom(
                  backgroundColor: _isDownloaded ? Colors.green : Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.pose.sourceImageUrl != null)
              Image.network(
                widget.pose.sourceImageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
              )
            else
              const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
            Container(color: Colors.black.withValues(alpha: 0.18)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: PoseOutlinePreview(
                template: widget.pose.template,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
