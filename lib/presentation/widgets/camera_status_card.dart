import 'package:alpen_ai_camera/presentation/controllers/camera_controller.dart';
import 'package:flutter/material.dart';

class CameraStatusCard extends StatelessWidget {
  const CameraStatusCard({required this.controller, super.key});

  // TODO: Present camera state, quick actions, and inline feedback in a reusable widget.
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera Module Skeleton',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              controller.statusLabel,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
