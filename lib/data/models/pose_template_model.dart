import 'package:alpen_ai_camera/data/models/pose_landmark_model.dart';
import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';
import 'package:alpen_ai_camera/domain/entities/pose_template.dart';

class PoseTemplateModel {
  const PoseTemplateModel({
    required this.id,
    required this.name,
    required this.landmarks,
    this.outlinePoints = const <PoseOutlinePoint>[],
    this.thumbnailPath,
    this.sourceImagePath,
    this.sourceImageWidth,
    this.sourceImageHeight,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final List<PoseLandmarkModel> landmarks;
  final List<PoseOutlinePoint> outlinePoints;
  final String? thumbnailPath;
  final String? sourceImagePath;
  final int? sourceImageWidth;
  final int? sourceImageHeight;
  final bool isFavorite;

  PoseTemplate toEntity() {
    return PoseTemplate(
      templateId: id,
      name: name,
      landmarks: landmarks.map((landmark) => landmark.toEntity()).toList(),
      outlinePoints: outlinePoints,
      thumbnailPath: thumbnailPath,
      sourceImagePath: sourceImagePath,
      sourceImageWidth: sourceImageWidth,
      sourceImageHeight: sourceImageHeight,
      isFavorite: isFavorite,
    );
  }

  factory PoseTemplateModel.fromEntity(PoseTemplate template) {
    return PoseTemplateModel(
      id: template.templateId,
      name: template.name,
      landmarks: template.landmarks
          .map(PoseLandmarkModel.fromEntity)
          .toList(),
      outlinePoints: template.outlinePoints,
      thumbnailPath: template.thumbnailPath,
      sourceImagePath: template.sourceImagePath,
      sourceImageWidth: template.sourceImageWidth,
      sourceImageHeight: template.sourceImageHeight,
      isFavorite: template.isFavorite,
    );
  }

  factory PoseTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawLandmarks = (json['landmarks'] as List<dynamic>? ?? <dynamic>[]);
    final rawOutline = (json['outlinePoints'] as List<dynamic>? ?? <dynamic>[]);
    return PoseTemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      landmarks: rawLandmarks
          .map(
            (landmark) => PoseLandmarkModel.fromJson(
              Map<String, dynamic>.from(landmark as Map),
            ),
          )
          .toList(),
      outlinePoints: rawOutline
          .map(
            (point) {
              final map = Map<String, dynamic>.from(point as Map);
              return PoseOutlinePoint(
                x: (map['x'] as num).toDouble(),
                y: (map['y'] as num).toDouble(),
              );
            },
          )
          .toList(),
      thumbnailPath: json['thumbnailPath'] as String?,
      sourceImagePath: json['sourceImagePath'] as String?,
      sourceImageWidth: json['sourceImageWidth'] as int?,
      sourceImageHeight: json['sourceImageHeight'] as int?,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'landmarks': landmarks.map((landmark) => landmark.toJson()).toList(),
      'outlinePoints': outlinePoints
          .map(
            (point) => <String, double>{
              'x': point.x,
              'y': point.y,
            },
          )
          .toList(),
      'thumbnailPath': thumbnailPath,
      'sourceImagePath': sourceImagePath,
      'sourceImageWidth': sourceImageWidth,
      'sourceImageHeight': sourceImageHeight,
      'isFavorite': isFavorite,
    };
  }
}
