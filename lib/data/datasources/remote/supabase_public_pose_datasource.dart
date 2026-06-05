import 'dart:io';

import 'package:alpen_ai_camera/data/models/public_pose_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SupabasePublicPoseDataSource {
  Future<List<PublicPoseModel>> getPoses({String? search, int limit, int offset});
  Future<void> incrementDownload(String poseId);
  Future<PublicPoseModel> insertPose(Map<String, dynamic> data);
  Future<String> uploadImage(String filePath, String fileName);
  Future<void> deletePose(String poseId);
}

class SupabasePublicPoseDataSourceImpl implements SupabasePublicPoseDataSource {
  SupabasePublicPoseDataSourceImpl({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<PublicPoseModel>> getPoses({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client.from('public_poses').select();

    if (search != null && search.isNotEmpty) {
      query = query.like('title', '%$search%');
    }

    final response = await query
        .order('download_count', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List)
        .map((json) => PublicPoseModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  @override
  Future<void> incrementDownload(String poseId) async {
    await _client.rpc('increment_download_count', params: {'pose_id': poseId});
  }

  @override
  Future<PublicPoseModel> insertPose(Map<String, dynamic> data) async {
    final response = await _client.from('public_poses').insert(data).select().single();
    return PublicPoseModel.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<String> uploadImage(String filePath, String fileName) async {
    final bytes = await File(filePath).readAsBytes();
    await _client.storage.from('pose_images').uploadBinary(
          fileName,
          bytes,
        );

    return _client.storage.from('pose_images').getPublicUrl(fileName);
  }

  @override
  Future<void> deletePose(String poseId) async {
    await _client.from('public_poses').delete().eq('id', poseId);
  }
}
