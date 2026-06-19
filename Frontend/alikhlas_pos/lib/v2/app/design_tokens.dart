import 'package:flutter/material.dart';

class V2DesignTokens {
  const V2DesignTokens._();

  static const ink = Color(0xFF13201F);
  static const inkMuted = Color(0xFF5B6B69);
  static const peacock = Color(0xFF0D6C68);
  static const peacockDeep = Color(0xFF084C4A);
  static const mint = Color(0xFF3DD6B4);
  static const copper = Color(0xFFC27846);
  static const pearl = Color(0xFFF7FAF8);
  static const glassWhite = Color(0xB8FFFFFF);
  static const glassStroke = Color(0xD9FFFFFF);

  static const space8 = 8.0;
  static const space16 = 16.0;

  static const radiusMd = 12.0;
  static const radiusXl = 20.0;

  static BorderRadius get radiusXlBorder => BorderRadius.circular(radiusXl);

  static final softPaneShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.09),
    blurRadius: 34,
    offset: const Offset(0, 18),
  );

  static final softControlShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 14,
    offset: const Offset(0, 6),
  );

  static LinearGradient get stageGradient => const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFE4F4F0),
      Color(0xFFF7F4EE),
      Color(0xFFE5ECF6),
      Color(0xFFF8FBFA),
    ],
    stops: [0, 0.36, 0.72, 1],
  );

  static LinearGradient get paneHighlight => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.white.withValues(alpha: 0.68),
      Colors.white.withValues(alpha: 0.08),
    ],
  );
}
