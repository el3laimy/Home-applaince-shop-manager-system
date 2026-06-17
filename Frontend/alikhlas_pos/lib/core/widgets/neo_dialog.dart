import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Neo-Glass Dialog — glassmorphism modal wrapper for alerts and forms.
///
/// Shows a frosted glass dialog with neon-cyan accent and smooth entry animation.
///
/// Static helpers:
/// ```dart
/// // Simple alert
/// NeoDialog.show(context, title: 'تنبيه', message: 'تمت العملية بنجاح');
///
/// // Confirmation
/// final confirmed = await NeoDialog.confirm(context,
///   title: 'حذف المنتج',
///   message: 'هل أنت متأكد من حذف هذا المنتج؟',
/// );
///
/// // Custom content
/// NeoDialog.showCustom(context,
///   title: 'إضافة عميل',
///   child: MyFormWidget(),
/// );
/// ```
class NeoDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? child;
  final List<Widget>? actions;
  final double maxWidth;
  final Color accentColor;

  const NeoDialog({
    super.key,
    this.title,
    this.message,
    this.child,
    this.actions,
    this.maxWidth = 460,
    this.accentColor = const Color(0xFF00F2FF),
  });

  // ═══════════════════════════════════════════════════════════════════════════
  //  STATIC HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Show a simple info alert
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'حسناً',
    Color accentColor = const Color(0xFF00F2FF),
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: _transition,
      pageBuilder: (ctx, a1, a2) => Center(
        child: NeoDialog(
          title: title,
          message: message,
          accentColor: accentColor,
          actions: [
            _NeoDialogButton(
              label: buttonLabel,
              color: accentColor,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a confirmation dialog — returns true if confirmed
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    Color accentColor = const Color(0xFFFF5E5E),
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: _transition,
      pageBuilder: (ctx, a1, a2) => Center(
        child: NeoDialog(
          title: title,
          message: message,
          accentColor: accentColor,
          actions: [
            _NeoDialogButton(
              label: cancelLabel,
              color: Colors.grey,
              isOutlined: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(width: 12),
            _NeoDialogButton(
              label: confirmLabel,
              color: accentColor,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// Show a custom content dialog — for forms, pickers, etc.
  static Future<T?> showCustom<T>(
    BuildContext context, {
    String? title,
    required Widget child,
    List<Widget>? actions,
    double maxWidth = 520,
    Color accentColor = const Color(0xFF00F2FF),
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: _transition,
      pageBuilder: (ctx, a1, a2) => Center(
        child: NeoDialog(
          title: title,
          child: child,
          actions: actions,
          maxWidth: maxWidth,
          accentColor: accentColor,
        ),
      ),
    );
  }

  /// Smooth scale + fade transition
  static Widget _transition(
    BuildContext context,
    Animation<double> a1,
    Animation<double> a2,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
    return Transform.scale(
      scale: 0.9 + 0.1 * curved.value,
      child: Opacity(
        opacity: curved.value,
        child: child,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.kNeoCardRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: maxWidth,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: const Color(0xE60F172A), // rgba(15,23,42,0.9)
                borderRadius: BorderRadius.circular(DesignTokens.kNeoCardRadius),
                border: Border.all(color: DesignTokens.glassBorder),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withAlpha(30),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Title Bar ──
                  if (title != null)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white.withAlpha(13)),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Accent dot
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 10),
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: accentColor.withAlpha(150), blurRadius: 10),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(title!, style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            )),
                          ),
                          // Close button
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.grey[500], size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // ── Content ──
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Text(message!, style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                        height: 1.6,
                      )),
                    ),

                  if (child != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: child!,
                      ),
                    ),

                  // ── Actions ──
                  if (actions != null && actions!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal button for NeoDialog — consistent with the dialog's design.
class _NeoDialogButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isOutlined;

  const _NeoDialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.isOutlined = false,
  });

  @override
  State<_NeoDialogButton> createState() => _NeoDialogButtonState();
}

class _NeoDialogButtonState extends State<_NeoDialogButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isOutlined
                ? null
                : LinearGradient(colors: [widget.color, widget.color.withAlpha(180)]),
            color: widget.isOutlined ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(12),
            border: widget.isOutlined
                ? Border.all(color: _hovering ? widget.color : widget.color.withAlpha(60))
                : null,
            boxShadow: _hovering && !widget.isOutlined
                ? [BoxShadow(color: widget.color.withAlpha(50), blurRadius: 12)]
                : null,
          ),
          child: Text(widget.label, style: TextStyle(
            color: widget.isOutlined ? widget.color : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          )),
        ),
      ),
    );
  }
}
