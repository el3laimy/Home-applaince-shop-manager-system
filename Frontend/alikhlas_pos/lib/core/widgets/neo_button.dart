
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Neo-Glass Button — frosted glass background with neon border hover and press effects.
///
/// Usage:
/// ```dart
/// NeoButton(
///   label: 'حفظ',
///   icon: Icons.save,
///   onPressed: () {},
///   color: DesignTokens.neonCyan,
/// )
/// ```
class NeoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;
  final bool isOutlined;
  final double height;
  final double? width;
  final double fontSize;
  final EdgeInsets? padding;

  const NeoButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = const Color(0xFF00F2FF),  // neonCyan
    this.isLoading = false,
    this.isOutlined = false,
    this.height = 44,
    this.width,
    this.fontSize = 14,
    this.padding,
  });

  /// Filled variant — gradient background
  const NeoButton.filled({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = const Color(0xFF00F2FF),
    this.isLoading = false,
    this.height = 44,
    this.width,
    this.fontSize = 14,
    this.padding,
  }) : isOutlined = false;

  /// Outlined variant — glass background, neon border
  const NeoButton.outlined({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = const Color(0xFF00F2FF),
    this.isLoading = false,
    this.height = 44,
    this.width,
    this.fontSize = 14,
    this.padding,
  }) : isOutlined = true;

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  bool _pressing = false;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _updateHover(bool value) {
    setState(() => _hovering = value);
    if (value) {
      _glowCtrl.forward();
    } else {
      _glowCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final effectiveColor = isDisabled ? widget.color.withAlpha(100) : widget.color;

    return MouseRegion(
      onEnter: (_) => _updateHover(true),
      onExit: (_) => _updateHover(false),
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) {
          setState(() => _pressing = false);
          widget.onPressed?.call();
        },
        onTapCancel: () => setState(() => _pressing = false),
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: widget.height,
              width: widget.width,
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              transform: _pressing
                  ? Matrix4.diagonal3Values(0.97, 0.97, 1)
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              decoration: widget.isOutlined
                  ? _outlinedDecoration(effectiveColor)
                  : _filledDecoration(effectiveColor),
              child: child,
            );
          },
          child: Row(
            mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.isOutlined ? effectiveColor : Colors.white,
                  ),
                ),
              ] else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18,
                      color: widget.isOutlined ? effectiveColor : Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isOutlined ? effectiveColor : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: widget.fontSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _filledDecoration(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withAlpha(180)],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: color.withAlpha((50 * _glowAnim.value).toInt()),
          blurRadius: 16 * _glowAnim.value,
          spreadRadius: 2 * _glowAnim.value,
        ),
      ],
    );
  }

  BoxDecoration _outlinedDecoration(Color color) {
    return BoxDecoration(
      color: DesignTokens.glassBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: _hovering ? color : color.withAlpha(60),
        width: _hovering ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withAlpha((40 * _glowAnim.value).toInt()),
          blurRadius: 12 * _glowAnim.value,
        ),
      ],
    );
  }
}
