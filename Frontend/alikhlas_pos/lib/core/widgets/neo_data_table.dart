import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Neo-Glass DataTable — glassmorphism table with frosted header, hover rows, and neon accents.
///
/// Usage:
/// ```dart
/// NeoDataTable(
///   columns: ['#', 'الاسم', 'الفئة', 'السعر'],
///   rows: products.map((p) => [
///     Text('${p.id}'),
///     Text(p.name),
///     Text(p.category),
///     Text(AppFormatters.currency(p.price)),
///   ]).toList(),
/// )
/// ```
class NeoDataTable extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  final List<double>? columnWidths;
  final ValueChanged<int>? onRowTap;
  final int? selectedIndex;
  final ScrollController? scrollController;
  final double headerHeight;
  final double rowHeight;

  const NeoDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnWidths,
    this.onRowTap,
    this.selectedIndex,
    this.scrollController,
    this.headerHeight = 48,
    this.rowHeight = 52,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DesignTokens.kNeoCardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: DesignTokens.neoGlassDecoration(
              borderRadius: DesignTokens.kNeoCardRadius,
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) => _buildRow(i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(13)),
        ),
      ),
      child: Row(
        children: List.generate(columns.length, (i) {
          final flex = columnWidths != null ? null : 1;
          final width = columnWidths?[i];
          return width != null
              ? SizedBox(
                  width: width,
                  child: Text(columns[i], style: _headerStyle()))
              : Expanded(
                  flex: flex!,
                  child: Text(columns[i], style: _headerStyle()));
        }),
      ),
    );
  }

  Widget _buildRow(int index) {
    final isSelected = selectedIndex == index;
    final cells = rows[index];

    return _NeoTableRow(
      isSelected: isSelected,
      onTap: onRowTap != null ? () => onRowTap!(index) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: rowHeight,
          child: Row(
            children: List.generate(cells.length, (i) {
              final flex = columnWidths != null ? null : 1;
              final width = columnWidths?[i];
              return width != null
                  ? SizedBox(width: width, child: cells[i])
                  : Expanded(flex: flex!, child: cells[i]);
            }),
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      color: Colors.grey[400],
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 0.5,
    );
  }
}

/// Stateful row for hover and selection effects.
class _NeoTableRow extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;

  const _NeoTableRow({
    required this.child,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_NeoTableRow> createState() => _NeoTableRowState();
}

class _NeoTableRowState extends State<_NeoTableRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? DesignTokens.neonCyan.withAlpha(20)
                : _hovering
                    ? Colors.white.withAlpha(10)
                    : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Colors.white.withAlpha(8)),
              right: widget.isSelected
                  ? BorderSide(color: DesignTokens.neonCyan, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  NEO LIST TILE — Glassmorphism list item
// ═══════════════════════════════════════════════════════════════════════════════

/// Neo-Glass ListTile — glass card with neon icon, hover glow, and click effect.
///
/// Usage:
/// ```dart
/// NeoListTile(
///   title: 'محمد أحمد',
///   subtitle: 'عميل مميز',
///   icon: Icons.person,
///   iconColor: DesignTokens.neonCyan,
///   trailing: Text('١٢,٥٠٠ ج.م'),
///   onTap: () {},
/// )
/// ```
class NeoListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isSelected;

  const NeoListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor = const Color(0xFF00F2FF),
    this.trailing,
    this.onTap,
    this.isSelected = false,
  });

  @override
  State<NeoListTile> createState() => _NeoListTileState();
}

class _NeoListTileState extends State<NeoListTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? DesignTokens.neonCyan.withAlpha(15)
                : _hovering
                    ? Colors.white.withAlpha(15)
                    : Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isSelected
                  ? DesignTokens.neonCyan.withAlpha(60)
                  : _hovering
                      ? Colors.white.withAlpha(25)
                      : Colors.white.withAlpha(10),
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: widget.iconColor.withAlpha(25), blurRadius: 12)]
                : null,
          ),
          child: Row(
            children: [
              // Icon
              if (widget.icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.iconColor.withAlpha(25),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 20),
                ),
                const SizedBox(width: 14),
              ],
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(widget.subtitle!, style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              // Trailing
              if (widget.trailing != null) ...[
                const SizedBox(width: 12),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
