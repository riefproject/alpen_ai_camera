import 'dart:isolate';

import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';
import 'package:alpen_ai_camera/domain/services/pose_outline_builder_service.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' as mlkit;
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart'
    as segmentation;

class _ExtractOutlineArgs {
  final List<double> confidences;
  final int width;
  final int height;
  final double threshold;

  _ExtractOutlineArgs({
    required this.confidences,
    required this.width,
    required this.height,
    required this.threshold,
  });
}

List<List<double>> _extractOutlineIsolate(_ExtractOutlineArgs args) {
  const maxPoints = 96;
  final width = args.width;
  final height = args.height;
  final confidences = args.confidences;
  final threshold = args.threshold;

  if (width <= 0 || height <= 0 || confidences.length < width * height) {
    throw StateError('Mask outline tubuh tidak valid.');
  }

  final componentMask = _largestComponentMaskIsolate(
    confidences,
    width: width,
    height: height,
    threshold: threshold,
  );

  final foregroundCount = componentMask.where((f) => f).length;
  final coverage = foregroundCount / confidences.length;
  if (coverage < 0.035) {
    throw StateError('Tubuh terlalu kecil atau tidak terlihat penuh.');
  }
  if (coverage > 0.82) {
    throw StateError('Gambar terlalu penuh atau background terlalu ramai.');
  }

  final step = (height ~/ 72).clamp(1, 12);
  final left = <List<double>>[];
  final right = <List<double>>[];

  for (var y = 0; y < height; y += step) {
    int? leftX;
    int? rightX;
    final rowStart = y * width;
    for (var x = 0; x < width; x++) {
      if (componentMask[rowStart + x]) {
        leftX ??= x;
        rightX = x;
      }
    }

    if (leftX == null || rightX == null) continue;

    left.add([leftX / width, y / height]);
    right.add([rightX / width, y / height]);
  }

  if (left.length < 12 || right.length < 12) {
    throw StateError('Outline tubuh terlalu tidak jelas.');
  }

  final outline = <List<double>>[...left, ...right.reversed];
  if (outline.length <= maxPoints) return outline;

  final s = outline.length / maxPoints;
  return [
    for (var i = 0; i < maxPoints; i++)
      outline[(i * s).floor().clamp(0, outline.length - 1)],
  ];
}

List<bool> _largestComponentMaskIsolate(
  List<double> confidences, {
  required int width,
  required int height,
  required double threshold,
}) {
  final total = width * height;
  final visited = List<bool>.filled(total, false);
  var bestComponent = <int>[];

  for (var index = 0; index < confidences.length; index++) {
    if (visited[index] || confidences[index] < threshold) continue;

    final component = <int>[];
    final queue = <int>[index];
    visited[index] = true;

    for (var cursor = 0; cursor < queue.length; cursor++) {
      final current = queue[cursor];
      component.add(current);
      final x = current % width;
      final y = current ~/ width;

      void visit(int next) {
        if (!visited[next] && confidences[next] >= threshold) {
          visited[next] = true;
          queue.add(next);
        }
      }

      if (x > 0) visit(current - 1);
      if (x < width - 1) visit(current + 1);
      if (y > 0) visit(current - width);
      if (y < height - 1) visit(current + width);
    }

    if (component.length > bestComponent.length) {
      bestComponent = component;
    }
  }

  final mask = List<bool>.filled(total, false);
  for (final index in bestComponent) {
    mask[index] = true;
  }
  return mask;
}

class PoseOutlineBuilderServiceImpl implements PoseOutlineBuilderService {
  PoseOutlineBuilderServiceImpl({segmentation.SelfieSegmenter? segmenter})
    : _segmenter =
          segmenter ??
          segmentation.SelfieSegmenter(
            mode: segmentation.SegmenterMode.single,
            enableRawSizeMask: false,
          );

  final segmentation.SelfieSegmenter _segmenter;

  @override
  Future<List<PoseOutlinePoint>> buildFromImage(String imagePath) async {
    final inputImage = mlkit.InputImage.fromFilePath(imagePath);
    final mask = await _segmenter.processImage(inputImage);
    if (mask == null || mask.confidences.isEmpty) {
      throw StateError('Outline tubuh tidak terbaca dari gambar.');
    }

    final width = mask.width;
    final height = mask.height;
    if (width <= 0 || height <= 0 || mask.confidences.length < width * height) {
      throw StateError('Mask outline tubuh tidak valid.');
    }

    final confidences = mask.confidences;
    final raw = await Isolate.run<List<List<double>>>(() {
      return _extractOutlineIsolate(_ExtractOutlineArgs(
        confidences: confidences,
        width: width,
        height: height,
        threshold: 0.62,
      ));
    });

    return raw
        .map((point) => PoseOutlinePoint(x: point[0], y: point[1]))
        .toList();
  }

  Future<void> close() => _segmenter.close();
}
