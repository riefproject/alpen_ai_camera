import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:alpen_ai_camera/domain/entities/public_pose.dart';

class PublicPoseModel {
  const PublicPoseModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    required this.templateData,
    this.sourceImageUrl,
    this.downloadCount = 0,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final Map<String, dynamic> templateData;
  final String? sourceImageUrl;
  final int downloadCount;
  final DateTime createdAt;

  PublicPose toEntity() {
    return PublicPose(
      id: id,
      userId: userId,
      title: title,
      description: description,
      template: PoseTemplateModel.fromJson(templateData).toEntity(),
      sourceImageUrl: sourceImageUrl,
      downloadCount: downloadCount,
      createdAt: createdAt,
    );
  }

  factory PublicPoseModel.fromEntity(PublicPose pose) {
    return PublicPoseModel(
      id: pose.id,
      userId: pose.userId,
      title: pose.title,
      description: pose.description,
      templateData: PoseTemplateModel.fromEntity(pose.template).toJson(),
      sourceImageUrl: pose.sourceImageUrl,
      downloadCount: pose.downloadCount,
      createdAt: pose.createdAt,
    );
  }

  factory PublicPoseModel.fromJson(Map<String, dynamic> json) {
    return PublicPoseModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      templateData: Map<String, dynamic>.from(json['template_data'] as Map),
      sourceImageUrl: json['source_image_url'] as String?,
      downloadCount: json['download_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'template_data': templateData,
      'source_image_url': sourceImageUrl,
      'download_count': downloadCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
