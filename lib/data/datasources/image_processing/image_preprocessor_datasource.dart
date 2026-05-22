import 'dart:typed_data';
import 'dart:io';

abstract class ImagePreprocessorDataSource {
  Future<Uint8List> preprocessStillImage(String imagePath);
  Future<Uint8List> preprocessFrame(
    Uint8List bytes, {
    required int width,
    required int height,
  });
}

class PassthroughImagePreprocessorDataSource
    implements ImagePreprocessorDataSource {
  const PassthroughImagePreprocessorDataSource();

  @override
  Future<Uint8List> preprocessStillImage(String imagePath) {
    return File(imagePath).readAsBytes();
  }

  @override
  Future<Uint8List> preprocessFrame(
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    return bytes;
  }
}
