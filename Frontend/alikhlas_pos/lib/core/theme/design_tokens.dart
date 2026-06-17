import 'dart:ui';
import 'package:flutter/material.dart';

/// ─── ALIkhlasPOS Design Tokens ───────────────────────────────────────────────
/// Centralized design constants and builder functions for a unified visual identity.

class DesignTokens {
  DesignTokens._();

  // ── Neon Accent Colors ─────────────────────────────────────────────────────
  static const Color neonCyan    = Color(0xFF00F2FF);   // Updated to match template
  static const Color neonPink    = Color(0xFFFF6B9D);
  static const Color neonPinkAlt = Color(0xFFFF00BD);   // Template --neon-pink
  static const Color neonGreen   = Color(0xFF43E97B);
  static const Color neonPurple  = Color(0xFFBC13FE);   // Template --neon-purple
  static const Color neonOrange  = Color(0xFFFFB800);
  static const Color neonBlue    = Color(0xFF4FACFE);
  static const Color neonRed     = Color(0xFFFF5E5E);

  // ── Surface Colors ─────────────────────────────────────────────────────────
  static const Color bgDark         = Color(0xFF0F172A);  // Template body
  static const Color surfaceDark    = Color(0xFF131A2A);
  static const Color cardDark       = Color(0xFF1A2236);
  static const Color cardDarkHover  = Color(0xFF1E2840);
  static const Color indigo950      = Color(0xFF1E1B4B);  // Template
  static const Color violet950      = Color(0xFF2E1065);  // Template

  // ── Glass Variables ────────────────────────────────────────────────────────
  static const Color glassBg     = Color(0x08FFFFFF);    // rgba(255,255,255,0.03)
  static const Color glassBorder = Color(0x1AFFFFFF);    // rgba(255,255,255,0.1)

  // ── Radii ──────────────────────────────────────────────────────────────────
  static const double kCardRadius     = 16.0;
  static const double kChipRadius     = 12.0;
  static const double kButtonRadius   = 12.0;
  static const double kNeoCardRadius  = 24.0;   // liquid-border cards
  static const double kNeoPanelRadius = 40.0;   // rounded-[2.5rem] panels

  // ── Spacing / Padding ──────────────────────────────────────────────────────
  static const double kPagePadding  = 24.0;
  static const double kPanelPadding = 20.0;
  static const double kCardGap      = 16.0;

  // ── Animation ──────────────────────────────────────────────────────────────
  static const Duration kAnimDuration = Duration(milliseconds: 250);

  // ══════════════════════════════════════════════════════════════════════════
  //  NEO-GLASS DECORATORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Translates `.neu-glass` CSS:
  /// frosted glass with backdrop blur, inset highlight, and outer shadow.
  /// Wrap content in [neoGlassBox] widget for full effect.
  static BoxDecoration neoGlassDecoration({
    double borderRadius = kNeoPanelRadius,
  }) {
    return BoxDecoration(
      color: glassBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: glassBorder),
      boxShadow: const [
        // Outer shadow
        BoxShadow(color: Color(0x4D000000), blurRadius: 20, offset: Offset(10, 10)),
        // Subtle inset highlight (simulated)
        BoxShadow(color: Color(0x0DFFFFFF), blurRadius: 5, spreadRadius: -2),
      ],
    );
  }

  /// Full Neo-Glass widget with efficient BackdropFilter.
  /// Wrapped in RepaintBoundary to avoid re-blurring every frame.
  static Widget neoGlassBox({
    required Widget child,
    double borderRadius = kNeoPanelRadius,
    EdgeInsets padding = const EdgeInsets.all(kPanelPadding),
  }) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: padding,
            decoration: neoGlassDecoration(borderRadius: borderRadius),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Translates `.liquid-border`: card with animated gradient border.
  /// Uses CustomPaint for efficient GPU-accelerated rendering.
  static Widget liquidBorderCard({
    required Widget child,
    double borderRadius = kNeoCardRadius,
    EdgeInsets padding = const EdgeInsets.all(kPanelPadding),
    double height = 160,
    bool hoverGlow = true,
  }) {
    return _LiquidBorderWidget(
      borderRadius: borderRadius,
      padding: padding,
      height: height,
      hoverGlow: hoverGlow,
      child: child,
    );
  }

  /// Holographic shimmer text widget.
  /// Uses a single AnimatedBuilder + ShaderMask — lightweight.
  static Widget holographicText({
    required String text,
    TextStyle? style,
  }) {
    return _HolographicTextWidget(text: text, style: style);
  }

  /// Translates the template body background:
  /// Multi-radial gradient with indigo/violet tones.
  static BoxDecoration neoPageBackground() {
    return const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topRight,
        radius: 1.5,
        colors: [indigo950, bgDark],
        stops: [0.0, 0.7],
      ),
    );
  }

  /// Full page background with overlapping gradients (matches template exactly).
  static Widget neoPageBackgroundWidget({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(color: bgDark),
      child: CustomPaint(
        painter: _NeoBackgroundPainter(),
        child: child,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EXISTING UTILITIES (preserved)
  // ══════════════════════════════════════════════════════════════════════════

  static List<BoxShadow> glowShadow(Color color, {double blur = 20, double spread = 0}) {
    return [
      BoxShadow(color: color.withAlpha(50), blurRadius: blur, spreadRadius: spread),
    ];
  }

  static BoxDecoration glowCardDecoration({
    required Color glowColor,
    required bool isDark,
  }) {
    return BoxDecoration(
      color: isDark ? cardDark : Colors.white,
      borderRadius: BorderRadius.circular(kCardRadius),
      border: Border.all(
        color: glowColor.withAlpha(isDark ? 80 : 60),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withAlpha(isDark ? 40 : 20),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration panelDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(220),
      borderRadius: BorderRadius.circular(kCardRadius),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(30),
      ),
    );
  }

  static Widget buildPageHeader({
    required BuildContext context,
    required String title,
    String? subtitle,
    List<Widget>? actions,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            )),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ],
        ),
        if (actions != null) Row(children: actions),
      ],
    );
  }

  static Widget buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color color = neonPurple,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withAlpha(180)],
        ),
        borderRadius: BorderRadius.circular(kButtonRadius),
        boxShadow: glowShadow(color, blur: 12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kButtonRadius),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(kPanelPadding),
      decoration: glowCardDecoration(glowColor: color, isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 10)],
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withAlpha(25),
                    borderRadius: BorderRadius.circular(kChipRadius),
                  ),
                  child: Text(badge, style: TextStyle(
                    color: badgeColor ?? color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  )),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  static Widget buildStockBar(int current, int min, {double width = 100}) {
    final ratio = min > 0 ? (current / (min * 3)).clamp(0.0, 1.0) : 1.0;
    final color = current <= min ? neonRed : (current <= min * 2 ? neonOrange : neonGreen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$current قطعة', style: TextStyle(
          color: color, fontWeight: FontWeight.bold, fontSize: 13,
        )),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 6,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerRight,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildCategoryBadge(String category, {Color? color}) {
    final c = color ?? _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.withAlpha(20),
        borderRadius: BorderRadius.circular(kChipRadius),
        border: Border.all(color: c.withAlpha(50)),
      ),
      child: Text(category, style: TextStyle(
        color: c, fontWeight: FontWeight.w600, fontSize: 12,
      )),
    );
  }

  static Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'ثلاجات':
      case 'ثلاجات ذكية': return neonCyan;
      case 'غسالات': return neonBlue;
      case 'شاشات':
      case 'شاشات oled': return neonPurple;
      case 'مكيفات':
      case 'مكيفات سبليت': return neonGreen;
      case 'أفران':
      case 'بوتاجاز': return neonOrange;
      case 'مايكروويف': return neonPink;
      default: return neonPurple;
    }
  }

  static BoxDecoration pageBackground({required bool isDark}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [bgDark, const Color(0xFF0F1629)]
            : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PRIVATE WIDGETS — Neo-Glass primitives
// ══════════════════════════════════════════════════════════════════════════════

/// Liquid Border Card: gradient-bordered card with hover animation.
class _LiquidBorderWidget extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final double height;
  final bool hoverGlow;

  const _LiquidBorderWidget({
    required this.child,
    required this.borderRadius,
    required this.padding,
    required this.height,
    required this.hoverGlow,
  });

  @override
  State<_LiquidBorderWidget> createState() => _LiquidBorderWidgetState();
}

class _LiquidBorderWidgetState extends State<_LiquidBorderWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LiquidBorderPainter(
            borderRadius: widget.borderRadius,
            opacity: widget.hoverGlow && _hovering ? 1.0 : 0.5,
          ),
          child: Container(
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: const Color(0x990F172A),  // rgba(15,23,42,0.6)
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// GPU-efficient gradient border painter for liquid-border effect.
class _LiquidBorderPainter extends CustomPainter {
  final double borderRadius;
  final double opacity;

  _LiquidBorderPainter({required this.borderRadius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          DesignTokens.neonCyan,
          Colors.transparent,
          DesignTokens.neonPurple,
          Colors.transparent,
          DesignTokens.neonPinkAlt,
        ],
        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect);
    paint.color = paint.color.withAlpha((opacity * 255).toInt());
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_LiquidBorderPainter old) => old.opacity != opacity;
}

/// Holographic shimmer text — runs a single lightweight animation.
class _HolographicTextWidget extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _HolographicTextWidget({required this.text, this.style});

  @override
  State<_HolographicTextWidget> createState() => _HolographicTextWidgetState();
}

class _HolographicTextWidgetState extends State<_HolographicTextWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 4.0 * _ctrl.value, 0),
              end: Alignment(1.0 + 4.0 * _ctrl.value, 0),
              colors: const [
                Colors.white,
                Color(0xFFA5B4FC),  // indigo-300
                DesignTokens.neonCyan,
                Colors.white,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: child!,
        );
      },
      child: Text(
        widget.text,
        style: (widget.style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w900,
          fontSize: widget.style?.fontSize ?? 24,
        ),
      ),
    );
  }
}

/// Multi-radial background painter — matches template body gradient.
class _NeoBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Radial gradient from top-right (indigo)
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 1.2,
        colors: [
          DesignTokens.indigo950.withAlpha(200),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint1);

    // Radial gradient from bottom-left (violet)
    final paint2 = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomLeft,
        radius: 1.2,
        colors: [
          DesignTokens.violet950.withAlpha(180),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

