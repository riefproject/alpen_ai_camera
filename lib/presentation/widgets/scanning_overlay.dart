import 'package:flutter/material.dart';

class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({
    required this.child,
    this.scanDuration = const Duration(milliseconds: 2200),
    this.onScanComplete,
    this.scanColor = Colors.lightGreenAccent,
    super.key,
  });

  final Widget child;
  final Duration scanDuration;
  final VoidCallback? onScanComplete;
  final Color scanColor;

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scanPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.scanDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onScanComplete?.call();
        }
      });
    _scanPosition = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _scanPosition,
          builder: (context, child) {
            return CustomPaint(
              painter: _ScanLinePainter(
                scanPosition: _scanPosition.value,
                scanColor: widget.scanColor,
                opacity: _controller.isCompleted ? 0.0 : 1.0,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({
    required this.scanPosition,
    required this.scanColor,
    required this.opacity,
  });

  final double scanPosition;
  final Color scanColor;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final scanY = size.height * scanPosition;

    // Glow behind the line
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scanColor.withValues(alpha: 0),
          scanColor.withValues(alpha: 0.25 * opacity),
          scanColor.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 30, size.width, 60), glowPaint);

    // Bright scan line
    final linePaint = Paint()
      ..color = scanColor.withValues(alpha: 0.85 * opacity)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), linePaint);

    // Side dots on the line
    final dotPaint = Paint()
      ..color = scanColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(20, scanY), 3, dotPaint);
    canvas.drawCircle(Offset(size.width - 20, scanY), 3, dotPaint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = scanColor.withValues(alpha: 0.50 * opacity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const bracketLen = 24.0;
    const margin = 16.0;
    final corners = [
      Offset(margin, margin),
      Offset(size.width - margin, margin),
      Offset(margin, size.height - margin),
      Offset(size.width - margin, size.height - margin),
    ];
    for (final corner in corners) {
      final isLeft = corner.dx == margin;
      final isTop = corner.dy == margin;
      canvas.drawLine(
        corner,
        Offset(corner.dx + (isLeft ? bracketLen : -bracketLen), corner.dy),
        bracketPaint,
      );
      canvas.drawLine(
        corner,
        Offset(corner.dx, corner.dy + (isTop ? bracketLen : -bracketLen)),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.scanPosition != scanPosition ||
        oldDelegate.opacity != opacity;
  }
}
