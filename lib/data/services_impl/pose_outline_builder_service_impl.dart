import 'package:alpen_ai_camera/domain/entities/pose_outline_point.dart';
import 'package:alpen_ai_camera/domain/services/pose_outline_builder_service.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' as mlkit;
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart'
    as segmentation;

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

    return _extractOutline(mask);
  }

  Future<void> close() => _segmenter.close();

  List<PoseOutlinePoint> _extractOutline(segmentation.SegmentationMask mask) {
    const threshold = 0.62;
    final width = mask.width;
    final height = mask.height;
    final confidences = mask.confidences;
    if (width <= 0 || height <= 0 || confidences.length < width * height) {
      throw StateError('Mask outline tubuh tidak valid.');
    }
    final componentMask = _largestComponentMask(
      confidences,
      width: width,
      height: height,
      threshold: threshold,
    );
    final foregroundCount = componentMask
        .where((isForeground) => isForeground)
        .length;
    final coverage = foregroundCount / confidences.length;

    if (coverage < 0.035) {
      throw StateError('Tubuh terlalu kecil atau tidak terlihat penuh.');
    }
    if (coverage > 0.82) {
      throw StateError('Gambar terlalu penuh atau background terlalu ramai.');
    }

    final step = (height / 72).ceil().clamp(1, 12);
    final left = <PoseOutlinePoint>[];
    final right = <PoseOutlinePoint>[];

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

      if (leftX == null || rightX == null) {
        continue;
      }

      left.add(PoseOutlinePoint(x: leftX / width, y: y / height));
      right.add(PoseOutlinePoint(x: rightX / width, y: y / height));
    }

    if (left.length < 12 || right.length < 12) {
      throw StateError('Outline tubuh terlalu tidak jelas.');
    }

    final outline = <PoseOutlinePoint>[...left, ...right.reversed];
    return _simplify(outline, maxPoints: 96);
  }

  List<bool> _largestComponentMask(
    List<double> confidences, {
    required int width,
    required int height,
    required double threshold,
  }) {
    final visited = List<bool>.filled(width * height, false);
    var bestComponent = <int>[];

    for (var index = 0; index < confidences.length; index++) {
      if (visited[index] || confidences[index] < threshold) {
        continue;
      }

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

        if (x > 0) {
          visit(current - 1);
        }
        if (x < width - 1) {
          visit(current + 1);
        }
        if (y > 0) {
          visit(current - width);
        }
        if (y < height - 1) {
          visit(current + width);
        }
      }

      if (component.length > bestComponent.length) {
        bestComponent = component;
      }
    }

    final mask = List<bool>.filled(width * height, false);
    for (final index in bestComponent) {
      mask[index] = true;
    }
    return mask;
  }

  List<PoseOutlinePoint> _simplify(
    List<PoseOutlinePoint> points, {
    required int maxPoints,
  }) {
    if (points.length <= maxPoints) {
      return points;
    }

    final step = points.length / maxPoints;
    return <PoseOutlinePoint>[
      for (var index = 0; index < maxPoints; index++)
        points[(index * step).floor().clamp(0, points.length - 1)],
    ];
  }
}
