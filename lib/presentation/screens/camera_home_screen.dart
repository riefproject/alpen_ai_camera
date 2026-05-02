import 'package:alpen_ai_camera/core/constants/app_constants.dart';
import 'package:alpen_ai_camera/data/services_impl/camera_service_impl.dart';
import 'package:alpen_ai_camera/presentation/controllers/camera_controller.dart';
import 'package:alpen_ai_camera/presentation/widgets/camera_status_card.dart';
import 'package:flutter/material.dart';

class CameraHomeScreen extends StatelessWidget {
  const CameraHomeScreen({super.key});

  // TODO: Compose the primary camera workflow screen and connect it to real state management.
  @override
  Widget build(BuildContext context) {
    final controller = CameraController(
      cameraService: const CameraServiceImpl(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.homeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: CameraStatusCard(controller: controller),
            ),
          ),
        ),
      ),
    );
  }
}
