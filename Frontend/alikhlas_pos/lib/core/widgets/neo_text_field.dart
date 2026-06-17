
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Neo-Glass TextField — frosted glass background, cyan focus ring, white text.
///
/// Usage:
/// ```dart
/// NeoTextField(
///   controller: _ctrl,
///   label: 'اسم العميل',
///   icon: Icons.person,
/// )
/// ```
class NeoTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final Color focusColor;
  final bool autofocus;

  const NeoTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.validator,
    this.focusColor = const Color(0xFF00F2FF),  // neonCyan
    this.autofocus = false,
  });

  @override
  State<NeoTextField> createState() => _NeoTextFieldState();
}

class _NeoTextFieldState extends State<NeoTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 6),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: DesignTokens.glassBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused
                  ? widget.focusColor
                  : DesignTokens.glassBorder,
              width: _focused ? 1.5 : 1,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: widget.focusColor.withAlpha(40), blurRadius: 12)]
                : null,
          ),
          child: Focus(
            onFocusChange: (f) => setState(() => _focused = f),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              readOnly: widget.readOnly,
              maxLines: widget.maxLines,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
              validator: widget.validator,
              autofocus: widget.autofocus,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: widget.focusColor,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: widget.icon != null
                    ? Icon(widget.icon, size: 20, color: _focused ? widget.focusColor : Colors.grey[500])
                    : null,
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
