import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;

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
      rotationDegrees: 0,
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

    return _toFrameModel(
      _bestLivePose(
        poses,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
      ),
      width: width,
      height: height,
      rotationDegrees: rotationDegrees,
    );
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
    required int rotationDegrees,
  }) {
    final landmarks = <PoseLandmarkModel>[];
    for (final entry in pose.landmarks.entries) {
      final point = _normalizePoint(
        entry.value.x,
        entry.value.y,
        width: width,
        height: height,
        rotationDegrees: rotationDegrees,
      );
      landmarks.add(
        PoseLandmarkModel(
          name: _landmarkName(entry.key),
          x: point.dx,
          y: point.dy,
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

  pose_mlkit.Pose _bestLivePose(
    List<pose_mlkit.Pose> poses, {
    required int width,
    required int height,
    required int rotationDegrees,
  }) {
    if (poses.length == 1) {
      return poses.first;
    }

    double poseScore(pose_mlkit.Pose pose) {
      final body = pose.landmarks.entries.where((entry) {
        return _bodyLandmarkTypes.contains(entry.key) &&
            entry.value.likelihood >= 0.35;
      }).toList();
      if (body.isEmpty) {
        return 0;
      }

      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = double.negativeInfinity;
      var maxY = double.negativeInfinity;
      for (final entry in body) {
        final point = _normalizePoint(
          entry.value.x,
          entry.value.y,
          width: width,
          height: height,
          rotationDegrees: rotationDegrees,
        );
        minX = math.min(minX, point.dx);
        minY = math.min(minY, point.dy);
        maxX = math.max(maxX, point.dx);
        maxY = math.max(maxY, point.dy);
      }

      final visibleScore = body.length / _bodyLandmarkTypes.length;
      final areaScore = ((maxX - minX).abs() * (maxY - minY).abs() * 4).clamp(
        0.0,
        1.0,
      );
      final centerX = (minX + maxX) / 2;
      final centerPenalty = (centerX - 0.5).abs().clamp(0.0, 0.5);
      return (visibleScore * 0.58) + (areaScore * 0.34) - centerPenalty * 0.28;
    }

    return poses.reduce(
      (best, pose) => poseScore(pose) > poseScore(best) ? pose : best,
    );
  }

  Offset _normalizePoint(
    double x,
    double y, {
    required int width,
    required int height,
    required int rotationDegrees,
  }) {
    final rotation = rotationDegrees % 360;
    final bool isRotated = rotation == 90 || rotation == 270;
    
    // ML Kit returns coordinates relative to the rotated image dimensions.
    final int rotatedWidth = isRotated ? height : width;
    final int rotatedHeight = isRotated ? width : height;

    final normalizedX = rotatedWidth <= 0 ? 0.0 : x / rotatedWidth;
    final normalizedY = rotatedHeight <= 0 ? 0.0 : y / rotatedHeight;

    // Mirror for front camera (270 usually means front camera on Android)
    final mirroredDx = rotation == 270 ? 1.0 - normalizedX : normalizedX;
    
    return Offset(mirroredDx.clamp(0.0, 1.0), normalizedY.clamp(0.0, 1.0));
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

const Set<pose_mlkit.PoseLandmarkType> _bodyLandmarkTypes =
    <pose_mlkit.PoseLandmarkType>{
      pose_mlkit.PoseLandmarkType.leftShoulder,
      pose_mlkit.PoseLandmarkType.rightShoulder,
      pose_mlkit.PoseLandmarkType.leftElbow,
      pose_mlkit.PoseLandmarkType.rightElbow,
      pose_mlkit.PoseLandmarkType.leftWrist,
      pose_mlkit.PoseLandmarkType.rightWrist,
      pose_mlkit.PoseLandmarkType.leftHip,
      pose_mlkit.PoseLandmarkType.rightHip,
      pose_mlkit.PoseLandmarkType.leftKnee,
      pose_mlkit.PoseLandmarkType.rightKnee,
      pose_mlkit.PoseLandmarkType.leftAnkle,
      pose_mlkit.PoseLandmarkType.rightAnkle,
      pose_mlkit.PoseLandmarkType.leftHeel,
      pose_mlkit.PoseLandmarkType.rightHeel,
      pose_mlkit.PoseLandmarkType.leftFootIndex,
      pose_mlkit.PoseLandmarkType.rightFootIndex,
    };
