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

  @override
  Widget build(BuildContext context) {
    if (filterName == null || filterName!.toLowerCase() == 'asli') {
      return child;
    }

    final effect = filterName!.toLowerCase();

    if (effect.contains('grayscale') || effect == 'b&w' || effect == 'bw') {
      final double i = intensity;
      const double r = 0.2126;
      const double g = 0.7152;
      const double b = 0.0722;
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(<double>[
          (1 - i) + i * r,
          i * g,
          i * b,
          0,
          0,
          i * r,
          (1 - i) + i * g,
          i * b,
          0,
          0,
          i * r,
          i * g,
          (1 - i) + i * b,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }

    if (effect == 'alami') {
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(<double>[
          1.05,
          0,
          0,
          0,
          10,
          0,
          1.02,
          0,
          0,
          5,
          0,
          0,
          0.95,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }

    if (effect == 'manis') {
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(<double>[
          1.1,
          0,
          0,
          0,
          20,
          0,
          0.95,
          0,
          0,
          10,
          0,
          0,
          0.95,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }

    if (effect == 'keriangan') {
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(<double>[
          1.12,
          0,
          0,
          0,
          12,
          0,
          1.06,
          0,
          0,
          8,
          0,
          0,
          0.92,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }

    if (effect == 'kristal') {
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(<double>[
          1.15,
          0,
          0,
          0,
          6,
          0,
          1.15,
          0,
          0,
          6,
          0,
          0,
          1.22,
          0,
          18,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }

    if (effect.contains('sepia')) {
      return ColorFiltered(
        colorFilter: ui.ColorFilter.matrix(<double>[
          0.393 * intensity + (1 - intensity),
          0.769 * intensity,
          0.189 * intensity,
          0,
          0,
          0.349 * intensity,
          0.686 * intensity + (1 - intensity),
          0.168 * intensity,
          0,
          0,
          0.272 * intensity,
          0.534 * intensity,
          0.131 * intensity + (1 - intensity),
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: child,
      );
    }

    // Default to child if no match
    return child;
  }
}
