import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';

import 'package:alpen_ai_camera/data/models/pose_frame_model.dart';
import 'package:alpen_ai_camera/data/models/pose_landmark_model.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' as mlkit;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as pose_mlkit;

abstract class PoseDetectorDataSource {
  Future<PoseFrameModel> detectFromImage(String imagePath);
  Future<PoseFrameModel> detectFromBytes(
    Uint8List bytes, {
    required int width,
    required int height,
    int rotationDegrees = 0,
    int formatRaw = 17,
    int bytesPerRow = 0,
  });
}

class MlKitPoseDetectorDataSource implements PoseDetectorDataSource {
  MlKitPoseDetectorDataSource({
    pose_mlkit.PoseDetector? streamPoseDetector,
    pose_mlkit.PoseDetector? stillImagePoseDetector,
  }) : _streamPoseDetector =
           streamPoseDetector ??
           pose_mlkit.PoseDetector(
             options: pose_mlkit.PoseDetectorOptions(
               model: pose_mlkit.PoseDetectionModel.accurate,
               mode: pose_mlkit.PoseDetectionMode.stream,
             ),
           ),
       _stillImagePoseDetector =
           stillImagePoseDetector ??
           pose_mlkit.PoseDetector(
             options: pose_mlkit.PoseDetectorOptions(
               model: pose_mlkit.PoseDetectionModel.accurate,
               mode: pose_mlkit.PoseDetectionMode.single,
             ),
           );

  final pose_mlkit.PoseDetector _streamPoseDetector;
  final pose_mlkit.PoseDetector _stillImagePoseDetector;

  @override
  Future<PoseFrameModel> detectFromImage(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final decodedImage = await _decodeImageSize(imageBytes);
    final inputImage = mlkit.InputImage.fromFilePath(imagePath);
    final poses = await _stillImagePoseDetector.processImage(inputImage);
    if (poses.length != 1) {
      throw StateError(
        poses.isEmpty
            ? 'Pose tidak terdeteksi. Pilih gambar dengan satu orang yang jelas.'
            : 'Gambar berisi lebih dari satu pose. Pilih satu orang sebagai referensi.',
      );
    }

    return _toFrameModel(
      poses.first,
      width: decodedImage.width.round(),
      height: decodedImage.height.round(),
    );
  }

  @override
  Future<PoseFrameModel> detectFromBytes(
    Uint8List bytes, {
    required int width,
    required int height,
    int rotationDegrees = 0,
    int formatRaw = 17,
    int bytesPerRow = 0,
  }) async {
    _validateFrameBytes(
      bytes,
      width: width,
      height: height,
      formatRaw: formatRaw,
      bytesPerRow: bytesPerRow,
    );
    final rotation =
        mlkit.InputImageRotationValue.fromRawValue(rotationDegrees) ??
        mlkit.InputImageRotation.rotation0deg;
    final format =
        mlkit.InputImageFormatValue.fromRawValue(formatRaw) ??
        mlkit.InputImageFormat.nv21;
    final inputImage = mlkit.InputImage.fromBytes(
      bytes: bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
    final poses = await _streamPoseDetector.processImage(inputImage);
    if (poses.isEmpty) {
      return PoseFrameModel(
        frameId: 'frame-${DateTime.now().microsecondsSinceEpoch}',
        landmarks: const <PoseLandmarkModel>[],
        width: width,
        height: height,
        capturedAt: DateTime.now(),
      );
    }

    return _toFrameModel(poses.first, width: width, height: height);
  }

  void _validateFrameBytes(
    Uint8List bytes, {
    required int width,
    required int height,
    required int formatRaw,
    required int bytesPerRow,
  }) {
    if (width <= 0 || height <= 0) {
      throw StateError('Frame kamera tidak valid: ukuran $width x $height.');
    }
    if (bytes.isEmpty) {
      throw StateError('Frame kamera kosong atau format tidak didukung.');
    }
    if (bytesPerRow <= 0) {
      throw StateError('Frame kamera tidak valid: bytesPerRow kosong.');
    }
    final supportedFormat = mlkit.InputImageFormatValue.fromRawValue(formatRaw);
    if (supportedFormat == null) {
      throw StateError('Format frame kamera tidak didukung: $formatRaw.');
    }
  }

  Future<void> close() async {
    await _streamPoseDetector.close();
    await _stillImagePoseDetector.close();
  }

  PoseFrameModel _toFrameModel(
    pose_mlkit.Pose pose, {
    required int width,
    required int height,
  }) {
    final landmarks = <PoseLandmarkModel>[];
    for (final entry in pose.landmarks.entries) {
      landmarks.add(
        PoseLandmarkModel(
          name: _landmarkName(entry.key),
          x: (entry.value.x / width).clamp(0.0, 1.0),
          y: (entry.value.y / height).clamp(0.0, 1.0),
          z: entry.value.z,
          visibility: entry.value.likelihood,
        ),
      );
    }

    return PoseFrameModel(
      frameId: 'frame-${DateTime.now().microsecondsSinceEpoch}',
      landmarks: landmarks,
      width: width,
      height: height,
      capturedAt: DateTime.now(),
    );
  }

  Future<Size> _decodeImageSize(Uint8List bytes) async {
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  String _landmarkName(pose_mlkit.PoseLandmarkType type) {
    switch (type) {
      case pose_mlkit.PoseLandmarkType.nose:
        return 'nose';
      case pose_mlkit.PoseLandmarkType.leftEyeInner:
        return 'leftEyeInner';
      case pose_mlkit.PoseLandmarkType.leftEye:
        return 'leftEye';
      case pose_mlkit.PoseLandmarkType.leftEyeOuter:
        return 'leftEyeOuter';
      case pose_mlkit.PoseLandmarkType.rightEyeInner:
        return 'rightEyeInner';
      case pose_mlkit.PoseLandmarkType.rightEye:
        return 'rightEye';
      case pose_mlkit.PoseLandmarkType.rightEyeOuter:
        return 'rightEyeOuter';
      case pose_mlkit.PoseLandmarkType.leftEar:
        return 'leftEar';
      case pose_mlkit.PoseLandmarkType.rightEar:
        return 'rightEar';
      case pose_mlkit.PoseLandmarkType.leftMouth:
        return 'leftMouth';
      case pose_mlkit.PoseLandmarkType.rightMouth:
        return 'rightMouth';
      case pose_mlkit.PoseLandmarkType.leftShoulder:
        return 'leftShoulder';
      case pose_mlkit.PoseLandmarkType.rightShoulder:
        return 'rightShoulder';
      case pose_mlkit.PoseLandmarkType.leftElbow:
        return 'leftElbow';
      case pose_mlkit.PoseLandmarkType.rightElbow:
        return 'rightElbow';
      case pose_mlkit.PoseLandmarkType.leftWrist:
        return 'leftWrist';
      case pose_mlkit.PoseLandmarkType.rightWrist:
        return 'rightWrist';
      case pose_mlkit.PoseLandmarkType.leftPinky:
        return 'leftPinky';
      case pose_mlkit.PoseLandmarkType.rightPinky:
        return 'rightPinky';
      case pose_mlkit.PoseLandmarkType.leftIndex:
        return 'leftIndex';
      case pose_mlkit.PoseLandmarkType.rightIndex:
        return 'rightIndex';
      case pose_mlkit.PoseLandmarkType.leftThumb:
        return 'leftThumb';
      case pose_mlkit.PoseLandmarkType.rightThumb:
        return 'rightThumb';
      case pose_mlkit.PoseLandmarkType.leftHip:
        return 'leftHip';
      case pose_mlkit.PoseLandmarkType.rightHip:
        return 'rightHip';
      case pose_mlkit.PoseLandmarkType.leftKnee:
        return 'leftKnee';
      case pose_mlkit.PoseLandmarkType.rightKnee:
        return 'rightKnee';
      case pose_mlkit.PoseLandmarkType.leftAnkle:
        return 'leftAnkle';
      case pose_mlkit.PoseLandmarkType.rightAnkle:
        return 'rightAnkle';
      case pose_mlkit.PoseLandmarkType.leftHeel:
        return 'leftHeel';
      case pose_mlkit.PoseLandmarkType.rightHeel:
        return 'rightHeel';
      case pose_mlkit.PoseLandmarkType.leftFootIndex:
        return 'leftFootIndex';
      case pose_mlkit.PoseLandmarkType.rightFootIndex:
        return 'rightFootIndex';
    }
  }
}
