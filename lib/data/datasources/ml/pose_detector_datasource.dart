import 'dart:typed_data';

import 'package:alpen_ai_camera/data/models/pose_frame_model.dart';

abstract class PoseDetectorDataSource {
  // TODO: Bridge the selected ML runtime and return raw pose detection output in a data-layer model format.
  Future<PoseFrameModel> detectFromImage(String imagePath);
  Future<PoseFrameModel> detectFromBytes(
    Uint8List bytes, {
    required int width,
    required int height,
  });
}
