import 'dart:math';

import 'package:alpen_ai_camera/data/datasources/remote/supabase_public_pose_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/public_pose.dart';
import 'package:alpen_ai_camera/domain/repositories/public_pose_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicPoseRepositoryImpl implements PublicPoseRepository {
  const PublicPoseRepositoryImpl({
    required SupabasePublicPoseDataSource dataSource,
  }) : _dataSource = dataSource;

  final SupabasePublicPoseDataSource _dataSource;

  @override
  Future<List<PublicPose>> getPoses({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final models = await _dataSource.getPoses(
      search: search,
      limit: limit,
      offset: offset,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> incrementDownload(String poseId) {
    return _dataSource.incrementDownload(poseId);
  }

  @override
  Future<PublicPose> uploadPose({
    required String title,
    required String description,
    required Map<String, dynamic> templateData,
    required String? sourceImagePath,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    String? sourceImageUrl;
    if (sourceImagePath != null) {
      final random = Random().nextInt(999999);
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}_$random.jpg';
      sourceImageUrl = await _dataSource.uploadImage(sourceImagePath, fileName);
    }

    final data = <String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'template_data': templateData,
      'source_image_url': sourceImageUrl,
    };

    final model = await _dataSource.insertPose(data);
    return model.toEntity();
  }

  @override
  Future<void> deletePose(String poseId) {
    return _dataSource.deletePose(poseId);
  }
}
