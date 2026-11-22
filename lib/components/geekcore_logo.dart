import 'package:flutter/material.dart';

/// GeekCoreLab Overclocked Molten Plasma Core Chip logo rendered as a crisp vector.
class GeekCoreLogo extends StatelessWidget {
  const GeekCoreLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.showShadow = false,
  });

  final double size;
  final double? borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 64 / 512);
    final Widget painted = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        size: Size.square(size),
        painter: const _GeekCoreChipPainter(),
      ),
    );

    if (!showShadow) {
      return SizedBox.square(dimension: size, child: painted);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: painted,
    );
  }
}

class _GeekCoreChipPainter extends CustomPainter {
  const _GeekCoreChipPainter();

  static const _bg = Color(0xFF080302);
  static const _copperDark = Color(0xFFEA580C);
  static const _copperMid = Color(0xFFF97316);
  static const _copperLight = Color(0xFFFB923C);
  static const _shelfAmber = Color(0xFFFDBA74);
  static const _carbonOuter = Color(0xFF261009);
  static const _carbonInner = Color(0xFF140805);
  static const _chamber = Color(0xFF431407);
  static const _plasmaYellow = Color(0xFFFDE047);
  static const _coreWhite = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 512.0;
    final sy = size.height / 512.0;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    void rect(double x, double y, double w, double h, Color color) {
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy), paint);
    }

    // Background
    rect(0, 0, 512, 512, _bg);

    // Left Pins (Red-Hot Copper / Amber)
    rect(32, 128, 64, 32, _copperDark);
    rect(32, 192, 64, 32, _copperMid);
    rect(32, 256, 64, 32, _copperLight);
    rect(32, 320, 64, 32, _copperMid);
    rect(32, 384, 64, 32, _copperDark);

    // Right Pins
    rect(416, 128, 64, 32, _copperDark);
    rect(416, 192, 64, 32, _copperMid);
    rect(416, 256, 64, 32, _copperLight);
    rect(416, 320, 64, 32, _copperMid);
    rect(416, 384, 64, 32, _copperDark);

    // Dark Carbon Body
    rect(96, 64, 320, 384, _carbonOuter);
    rect(112, 80, 288, 352, _carbonInner);

    // Top Thermal Vent / Exhaust Notch
    rect(208, 64, 96, 32, _copperMid);
    rect(224, 64, 64, 16, _plasmaYellow);

    // Superheated Chamber Recess
    rect(160, 128, 192, 224, _chamber);

    // The Molten Plasma G-Core
    rect(192, 160, 128, 32, _copperDark); // Top bar of G
    rect(192, 192, 32, 128, _copperMid); // Left wall
    rect(192, 288, 128, 32, _copperDark); // Bottom bar
    rect(288, 224, 32, 96, _copperMid); // Right leg
    rect(256, 224, 32, 32, _shelfAmber); // Shelf

    // Incandescent Fusion Core
    rect(224, 192, 48, 48, _plasmaYellow);
    rect(232, 200, 32, 32, _coreWhite);

    // Thermal Venting Sparks / Energy Bleed
    rect(144, 112, 16, 16, _copperDark);
    rect(352, 112, 16, 16, _copperDark);
    rect(144, 368, 16, 16, _copperDark);
    rect(352, 368, 16, 16, _copperDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
