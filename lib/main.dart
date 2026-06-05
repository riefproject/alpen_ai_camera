import 'package:alpen_ai_camera/core/constants/app_constants.dart';
import 'package:alpen_ai_camera/presentation/controllers/auth_controller.dart';
import 'package:alpen_ai_camera/presentation/screens/camera_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authController = AuthController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await Hive.initFlutter();
  await Hive.openBox<bool>('favorites_box');
  await Hive.openBox<String>('uploaded_poses');
  runApp(const AlpenAiCameraApp());
}

class AlpenAiCameraApp extends StatelessWidget {
  const AlpenAiCameraApp({super.key});

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
