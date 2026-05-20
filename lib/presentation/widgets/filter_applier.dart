import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class FilterApplier extends StatelessWidget {
  final Widget child;
  final String? filterName;
  final double intensity;

  const FilterApplier({
    super.key,
    required this.child,
    this.filterName,
    this.intensity = 0.5,
  });

  static List<double>? getFilterMatrix(String filterName, {double intensity = 0.5}) {
    final effect = filterName.toLowerCase();

    if (effect.contains('grayscale') || effect == 'b&w' || effect == 'bw') {
      final double i = intensity;
      const double r = 0.2126;
      const double g = 0.7152;
      const double b = 0.0722;
      return <double>[
        (1 - i) + i * r, i * g, i * b, 0, 0,
        i * r, (1 - i) + i * g, i * b, 0, 0,
        i * r, i * g, (1 - i) + i * b, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }

    if (effect == 'alami') {
      return <double>[
        1.05, 0, 0, 0, 10,
        0, 1.02, 0, 0, 5,
        0, 0, 0.95, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }

    if (effect == 'manis') {
      return <double>[
        1.1, 0, 0, 0, 20,
        0, 0.95, 0, 0, 10,
        0, 0, 0.95, 0, 15,
        0, 0, 0, 1, 0,
      ];
    }

    if (effect == 'keriangan') {
      return <double>[
        1.12, 0, 0, 0, 12,
        0, 1.06, 0, 0, 8,
        0, 0, 0.92, 0, 0,
        0, 0, 0, 1, 0,
      ];
    }

    if (effect == 'kristal') {
      return <double>[
        1.15, 0, 0, 0, 6,
        0, 1.15, 0, 0, 6,
        0, 0, 1.22, 0, 18,
        0, 0, 0, 1, 0,
      ];
    }

    if (effect.contains('sepia')) {
      return <double>[
        0.393 * intensity + (1 - intensity), 0.769 * intensity, 0.189 * intensity, 0, 0,
        0.349 * intensity, 0.686 * intensity + (1 - intensity), 0.168 * intensity, 0, 0,
        0.272 * intensity, 0.534 * intensity, 0.131 * intensity + (1 - intensity), 0, 0,
        0, 0, 0, 1, 0,
      ];
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (filterName == null || filterName!.toLowerCase() == 'asli') {
      return child;
    }

    final matrix = getFilterMatrix(filterName!, intensity: intensity);
    
    if (matrix != null) {
      final double i = intensity;
      const double r = 0.2126;
      const double g = 0.7152;
      const double b = 0.0722;
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(matrix),
        child: child,
      );
    }

    // Default to child if no match
    return child;
  }
}
