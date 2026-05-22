import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';

abstract class PoseOutlineBuilderService {
  Future<List<PoseOutlinePoint>> buildFromImage(String imagePath);
}
