import 'dart:async';

import 'package:alpen_ai_camera/data/datasources/local/pose_template_local_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/public_pose.dart';
import 'package:alpen_ai_camera/presentation/controllers/public_pose_controller.dart';
import 'package:alpen_ai_camera/presentation/screens/public_pose_detail_screen.dart';
import 'package:alpen_ai_camera/presentation/widgets/pose_ghost_overlay.dart';
import 'package:flutter/material.dart';

class PublicPoseBrowseScreen extends StatefulWidget {
  const PublicPoseBrowseScreen({required this.controller, super.key});

  final PublicPoseController controller;

  @override
  State<PublicPoseBrowseScreen> createState() => _PublicPoseBrowseScreenState();
}

class _PublicPoseBrowseScreenState extends State<PublicPoseBrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    widget.controller.fetchPoses(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChange);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.controller.fetchPoses();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.controller.setSearchQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        title: const Text('Pose Publik'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1B1B1B),
                hintText: 'Cari pose...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: controller.isLoading && controller.poses.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : controller.poses.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada pose',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.78,
                            ),
                        itemCount:
                            controller.poses.length + (controller.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= controller.poses.length) {
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          }

                          final pose = controller.poses[index];
                          return _PublicPoseCard(
                            pose: pose,
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      PublicPoseDetailScreen(pose: pose),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PublicPoseCard extends StatelessWidget {
  const _PublicPoseCard({required this.pose, required this.onTap});

  final PublicPose pose;
  final VoidCallback onTap;

  Widget _buildPreview() {
    final sourceImageUrl = pose.sourceImageUrl;
    if (sourceImageUrl == null || sourceImageUrl.isEmpty) {
      return Center(
        child: FittedBox(
          child: Icon(
            Icons.accessibility_new,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(sourceImageUrl, fit: BoxFit.contain),
        Container(color: Colors.black.withValues(alpha: 0.18)),
        Padding(
          padding: const EdgeInsets.all(2),
          child: PoseOutlinePreview(template: pose.template, color: Colors.white),
        ),
      ],
    );
  }

  Future<bool> _isDownloaded() async {
    final dataSource = HivePoseTemplateLocalDataSource();
    return dataSource.exists('public-${pose.id}');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
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
                    child: FutureBuilder<bool>(
                      future: _isDownloaded(),
                      builder: (context, snapshot) {
                        final downloaded = snapshot.data ?? false;
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPreview(),
                            if (downloaded)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.lightGreenAccent,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
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
                      pose.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.download,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${pose.downloadCount}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
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
