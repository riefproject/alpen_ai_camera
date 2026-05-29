import 'dart:io';

double translateX(
    double x, int rotation, double sizeWidth, double imageWidth, double imageHeight) {
  switch (rotation) {
    case 90:
      return x * sizeWidth / imageHeight;
    case 270:
      return sizeWidth - x * sizeWidth / imageHeight;
    default:
      return x * sizeWidth / imageWidth;
  }
}

double translateY(
    double y, int rotation, double sizeHeight, double imageWidth, double imageHeight) {
  switch (rotation) {
    case 90:
    case 270:
      return y * sizeHeight / imageWidth;
    default:
      return y * sizeHeight / imageHeight;
  }
}

void main() {
  print('90 deg: X maps to X/height, Y maps to Y/width');
  print('270 deg: X maps to 1 - X/height, Y maps to Y/width');
}
