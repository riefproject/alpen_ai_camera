import 'package:alpen_ai_camera/core/constants/app_constants.dart';
import 'package:alpen_ai_camera/presentation/screens/camera_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<bool>('favorites_box');
  runApp(const AlpenAiCameraApp());
}

class AlpenAiCameraApp extends StatelessWidget {
  const AlpenAiCameraApp({super.key});

  // TODO: Centralize app-wide routing, theming, and dependency wiring here.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const CameraHomeScreen(),
    );
  }
}
