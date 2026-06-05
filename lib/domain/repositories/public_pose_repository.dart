import 'package:alpen_ai_camera/domain/entities/public_pose.dart';

abstract class PublicPoseRepository {
  Future<List<PublicPose>> getPoses({String? search, int limit = 20, int offset = 0});
  Future<void> incrementDownload(String poseId);
  Future<PublicPose> uploadPose({
    required String title,
    required String description,
    required Map<String, dynamic> templateData,
    required String? sourceImagePath,
  });
  Future<void> deletePose(String poseId);
}
