import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

class PublicPose {
  const PublicPose({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.template,
    this.sourceImageUrl,
    this.downloadCount = 0,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final PoseTemplate template;
  final String? sourceImageUrl;
  final int downloadCount;
  final DateTime createdAt;
}
