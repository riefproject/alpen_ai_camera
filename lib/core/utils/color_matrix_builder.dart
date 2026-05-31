import 'dart:math' as math;

/// Utility for building combined 5x4 color filter matrices from adjustment parameters.
/// Each method returns a 20-element List<double> representing a 5x4 color transformation matrix.
class ColorMatrixBuilder {
  // Identity matrix (no change)
  static List<double> identity() {
    return <double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Multiply two 5x4 matrices (represented as 20-element lists).
  static List<double> multiply(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        if (col == 4) {
          sum += a[row * 5 + 4];
        }
        result[row * 5 + col] = sum;
      }
    }
    return result;
  }

  /// Brightness: -1.0 to 1.0 (0 = no change)
  static List<double> brightness(double value) {
    final v = value * 255;
    return <double>[
      1, 0, 0, 0, v,
      0, 1, 0, 0, v,
      0, 0, 1, 0, v,
      0, 0, 0, 1, 0,
    ];
  }

  /// Contrast: -1.0 to 1.0 (0 = no change)
  static List<double> contrast(double value) {
    final c = 1 + value;
    final t = 128 * (1 - c);
    return <double>[
      c, 0, 0, 0, t,
      0, c, 0, 0, t,
      0, 0, c, 0, t,
      0, 0, 0, 1, 0,
    ];
  }

  /// Saturation: -1.0 to 1.0 (0 = no change)
  static List<double> saturation(double value) {
    final s = 1 + value;
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final sr = (1 - s) * lr;
    final sg = (1 - s) * lg;
    final sb = (1 - s) * lb;
    return <double>[
      sr + s, sg, sb, 0, 0,
      sr, sg + s, sb, 0, 0,
      sr, sg, sb + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Exposure: -1.0 to 1.0 (0 = no change)
  static List<double> exposure(double value) {
    final e = math.pow(2, value).toDouble();
    return <double>[
      e, 0, 0, 0, 0,
      0, e, 0, 0, 0,
      0, 0, e, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  /// Highlights: -1.0 to 1.0 (0 = no change)
  /// Adjusts the brighter parts of the image.
  static List<double> highlights(double value) {
    final v = value * 50;
    return <double>[
      1, 0, 0, 0, v,
      0, 1, 0, 0, v,
      0, 0, 1, 0, v,
      0, 0, 0, 1, 0,
    ];
  }

  /// Shadows: -1.0 to 1.0 (0 = no change)
  /// Lifts or darkens the shadow areas.
  static List<double> shadows(double value) {
    final v = value * 40;
    return <double>[
      1, 0, 0, 0, v,
      0, 1, 0, 0, v,
      0, 0, 1, 0, v,
      0, 0, 0, 1, 0,
    ];
  }

  /// Temperature: -1.0 (cool/blue) to 1.0 (warm/yellow) (0 = no change)
  static List<double> temperature(double value) {
    final r = value * 30;
    final b = -value * 30;
    return <double>[
      1, 0, 0, 0, r,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  /// Tint: -1.0 (green) to 1.0 (magenta) (0 = no change)
  static List<double> tint(double value) {
    final g = -value * 30;
    final r = value * 15;
    final b = value * 15;
    return <double>[
      1, 0, 0, 0, r,
      0, 1, 0, 0, g,
      0, 0, 1, 0, b,
      0, 0, 0, 1, 0,
    ];
  }

  /// Brilliance: -1.0 to 1.0 (0 = no change)
  /// A combination of brightness + contrast that brightens shadows more than highlights.
  static List<double> brilliance(double value) {
    final brightness = value * 0.3;
    final contrast = value * 0.3;
    final bMatrix = ColorMatrixBuilder.brightness(brightness);
    final cMatrix = ColorMatrixBuilder.contrast(contrast);
    return multiply(bMatrix, cMatrix);
  }

  /// Vignette is handled via a custom painter, not a color matrix.
  /// We return identity here as a placeholder. The actual vignette is painted as a gradient overlay.
  static List<double> vignette(double value) {
    return identity();
  }

  /// Sharpness is also handled post-processing. Return identity.
  static List<double> sharpness(double value) {
    return identity();
  }

  /// Combine all adjustment parameters into a single color matrix.
  static List<double> buildCombined({
    double brightnessVal = 0,
    double contrastVal = 0,
    double saturationVal = 0,
    double exposureVal = 0,
    double highlightsVal = 0,
    double shadowsVal = 0,
    double temperatureVal = 0,
    double tintVal = 0,
    double brillianceVal = 0,
  }) {
    var result = identity();

    if (exposureVal != 0) result = multiply(result, exposure(exposureVal));
    if (brightnessVal != 0) result = multiply(result, brightness(brightnessVal));
    if (contrastVal != 0) result = multiply(result, contrast(contrastVal));
    if (highlightsVal != 0) result = multiply(result, highlights(highlightsVal));
    if (shadowsVal != 0) result = multiply(result, shadows(shadowsVal));
    if (saturationVal != 0) result = multiply(result, saturation(saturationVal));
    if (temperatureVal != 0) result = multiply(result, temperature(temperatureVal));
    if (tintVal != 0) result = multiply(result, tint(tintVal));
    if (brillianceVal != 0) result = multiply(result, brilliance(brillianceVal));

    return result;
  }
}
