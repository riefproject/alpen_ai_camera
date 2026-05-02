import 'dart:typed_data';

abstract class ImagePreprocessorDataSource {
  // TODO: Apply low-level image cleanup, resizing, normalization, and conversion before pose detection.
  Future<Uint8List> preprocessStillImage(String imagePath);
  Future<Uint8List> preprocessFrame(
    Uint8List bytes, {
    required int width,
    required int height,
  });
}
