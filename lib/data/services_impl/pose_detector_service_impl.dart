import 'dart:typed_data';

import 'package:alpen_ai_camera/data/datasources/ml/pose_detector_datasource.dart';
import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';
import 'package:alpen_ai_camera/domain/services/pose_detector_service.dart';

class PoseDetectorServiceImpl implements PoseDetectorService {
  const PoseDetectorServiceImpl({
    required PoseDetectorDataSource poseDetectorDataSource,
  }) : _poseDetectorDataSource = poseDetectorDataSource;

  // TODO: Adapt the selected ML detector data source into a stable domain-level pose detection service.
  final PoseDetectorDataSource _poseDetectorDataSource;

  PoseDetectorDataSource get poseDetectorDataSource => _poseDetectorDataSource;

  @override
  Future<PoseFrame> detectFromImage(String imagePath) {
    throw UnimplementedError(
      'PoseDetectorServiceImpl.detectFromImage belum diimplementasikan.',
    );
  }

  @override
  Future<PoseFrame> detectFromBytes(
    Uint8List bytes, {
    required int width,
    required int height,
  }) {
    throw UnimplementedError(
      'PoseDetectorServiceImpl.detectFromBytes belum diimplementasikan.',
    );
  }
}
