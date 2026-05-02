import 'package:alpen_ai_camera/data/models/pose_landmark_model.dart';
import 'package:alpen_ai_camera/domain/entities/pose_frame.dart';

class PoseFrameModel {
  const PoseFrameModel({
    required this.frameId,
    required this.landmarks,
    required this.width,
    required this.height,
    required this.capturedAt,
  });

  // TODO: Carry detector output in a data-friendly shape before it is mapped into a domain pose frame.
  final String frameId;
  final List<PoseLandmarkModel> landmarks;
  final int width;
  final int height;
  final DateTime capturedAt;

  PoseFrame toEntity() {
    throw UnimplementedError(
      'PoseFrameModel.toEntity belum diimplementasikan.',
    );
  }
}
