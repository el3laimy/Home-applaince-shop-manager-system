import 'dart:ui';
import 'package:flutter/material.dart';

/// ─── ALIkhlasPOS Design Tokens ───────────────────────────────────────────────
/// Centralized design constants and builder functions for a unified visual identity.

class DesignTokens {
  DesignTokens._();

  // ── Neon Accent Colors ─────────────────────────────────────────────────────
  static const Color neonCyan    = Color(0xFF00E5FF);
  static const Color neonPink    = Color(0xFFFF6B9D);
  static const Color neonGreen   = Color(0xFF43E97B);
  static const Color neonPurple  = Color(0xFF6C63FF);
  static const Color neonOrange  = Color(0xFFFFB800);
  static const Color neonBlue    = Color(0xFF4FACFE);
  static const Color neonRed     = Color(0xFFFF5E5E);

  // ── Surface Colors ─────────────────────────────────────────────────────────
  static const Color bgDark         = Color(0xFF0B0F19);
  static const Color surfaceDark    = Color(0xFF131A2A);
  static const Color cardDark       = Color(0xFF1A2236);
  static const Color cardDarkHover  = Color(0xFF1E2840);

  // ── Radii ──────────────────────────────────────────────────────────────────
  static const double kCardRadius   = 16.0;
  static const double kChipRadius   = 12.0;
  static const double kButtonRadius = 12.0;

  // ── Spacing / Padding ──────────────────────────────────────────────────────
  static const double kPagePadding  = 24.0;
  static const double kPanelPadding = 20.0;
  static const double kCardGap      = 16.0;

  // ── Animation ──────────────────────────────────────────────────────────────
  static const Duration kAnimDuration = Duration(milliseconds: 250);

  // ── Glow Box Shadow ────────────────────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double blur = 20, double spread = 0}) {
    return [
      BoxShadow(color: color.withAlpha(50), blurRadius: blur, spreadRadius: spread),
    ];
  }

  // ── Neon-bordered Card Decoration ──────────────────────────────────────────
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

  // ── Glassmorphism Panel Decoration ─────────────────────────────────────────
  static BoxDecoration panelDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark ? Colors.white.withAlpha(8) : Colors.white.withAlpha(220),
      borderRadius: BorderRadius.circular(kCardRadius),
      border: Border.all(
        color: isDark ? Colors.white.withAlpha(15) : Colors.grey.withAlpha(30),
      ),
    );
  }

  // ── Standard Page Header ───────────────────────────────────────────────────
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

  // ── Gradient Action Button ─────────────────────────────────────────────────
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

  // ── Stat Card with Neon Glow ───────────────────────────────────────────────
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

  // ── Stock Level Bar ────────────────────────────────────────────────────────
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

  // ── Category Badge ─────────────────────────────────────────────────────────
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

  // ── Page Background Gradient ───────────────────────────────────────────────
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
