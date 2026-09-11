part of '../v2_app.dart';

class _Screen extends StatelessWidget {
  const _Screen({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  Text(subtitle, style: const TextStyle(color: _mutedInk)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: child),
      ],
    );
  }
}

class _GlassStage extends StatelessWidget {
  const _GlassStage({required this.child, this.background});

  final Widget child;
  final UiBackgroundSnapshot? background;

  @override
  Widget build(BuildContext context) {
    final imagePath = background?.imagePath;
    final imageFile = imagePath == null ? null : File(imagePath);
    final hasImage = imageFile != null && imageFile.existsSync();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: _backgroundGradient(background?.preset ?? 'aurora'),
            ),
          ),
          if (hasImage)
            Image.file(
              imageFile,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          if (hasImage)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: _LiquidBackdropPainter(
                preset: background?.preset ?? 'aurora',
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlassPane extends StatefulWidget {
  const _GlassPane({
    required this.child,
    this.width,
    this.padding,
    this.enableBlur = false,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final bool enableBlur;

  @override
  State<_GlassPane> createState() => _GlassPaneState();
}

class _GlassPaneState extends State<_GlassPane> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = V2DesignTokens.radiusXlBorder;
    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: V2DesignTokens.paneSurface,
        borderRadius: radius,
        border: Border.all(
          color: _hovered
              ? Colors.white.withValues(alpha: 0.98)
              : V2DesignTokens.glassStroke,
          width: _hovered ? 1.35 : 1,
        ),
        boxShadow: [
          V2DesignTokens.softPaneShadow,
          BoxShadow(
            color: V2DesignTokens.mint.withValues(
              alpha: _hovered ? 0.12 : 0.05,
            ),
            blurRadius: _hovered ? 28 : 18,
            offset: const Offset(-8, -6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LiquidPanePainter(hoverProgress: _hovered ? 1 : 0),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: V2DesignTokens.paneHighlight,
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Padding(
              padding:
                  widget.padding ??
                  const EdgeInsets.all(V2DesignTokens.space16),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
    final pane = ClipRRect(
      borderRadius: radius,
      child: widget.enableBlur
          ? BackdropFilter(filter: _liquidGlassFilter, child: surface)
          : surface,
    );
    final interactivePane = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: _hovered ? 1.004 : 1,
        child: pane,
      ),
    );
    return widget.width == null
        ? interactivePane
        : SizedBox(width: widget.width, child: interactivePane);
  }
}

final ImageFilter _liquidGlassFilter = ImageFilter.compose(
  inner: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  outer: ImageFilter.matrix(
    Float64List.fromList(const [
      1.012,
      0,
      0,
      0,
      0,
      1.012,
      0,
      0,
      0,
      0,
      1,
      0,
      -3,
      -2,
      0,
      1,
    ]),
  ),
);

class _LiquidPanePainter extends CustomPainter {
  const _LiquidPanePainter({required this.hoverProgress});

  final double hoverProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final diagonalShine = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + hoverProgress * 0.55, -1),
        end: Alignment(0.85 + hoverProgress * 0.55, 1),
        colors: [
          Colors.white.withValues(alpha: 0.00),
          Colors.white.withValues(alpha: 0.24 + hoverProgress * 0.12),
          V2DesignTokens.mint.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.00),
        ],
        stops: const [0.14, 0.34, 0.48, 0.72],
      ).createShader(rect);
    canvas.drawRect(rect, diagonalShine);

    final topEdge = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: 0.00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2.4));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 2.4), topEdge);

    final leftEdge = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.72),
          V2DesignTokens.mint.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.00),
        ],
      ).createShader(Rect.fromLTWH(0, 0, 2.2, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, 2.2, size.height), leftEdge);

    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.20 + hoverProgress * 0.10);
    final firstRipple = Path()
      ..moveTo(size.width * 0.05, size.height * 0.28)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.18,
        size.width * 0.48,
        size.height * 0.38,
        size.width * 0.74,
        size.height * 0.24,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.17,
        size.width * 0.96,
        size.height * 0.22,
        size.width * 1.08,
        size.height * 0.14,
      );
    canvas.drawPath(firstRipple, ripple);

    final secondRipple = Path()
      ..moveTo(size.width * 0.20, size.height * 0.78)
      ..cubicTo(
        size.width * 0.40,
        size.height * 0.66,
        size.width * 0.62,
        size.height * 0.84,
        size.width * 0.92,
        size.height * 0.70,
      );
    canvas.drawPath(
      secondRipple,
      ripple..color = V2DesignTokens.iris.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidPanePainter oldDelegate) {
    return oldDelegate.hoverProgress != hoverProgress;
  }
}

class _LiquidBackdropPainter extends CustomPainter {
  const _LiquidBackdropPainter({required this.preset});

  final String preset;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = _backgroundPalette(preset);
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.$1.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.02),
          palette.$2.withValues(alpha: 0.20),
        ],
        stops: const [0, 0.48, 1],
      ).createShader(Offset.zero & size);

    final coolRibbon = Path()
      ..moveTo(-size.width * 0.10, size.height * 0.12)
      ..cubicTo(
        size.width * 0.24,
        -size.height * 0.02,
        size.width * 0.58,
        size.height * 0.16,
        size.width * 1.10,
        size.height * 0.03,
      )
      ..lineTo(size.width * 1.10, size.height * 0.34)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.45,
        size.width * 0.24,
        size.height * 0.27,
        -size.width * 0.10,
        size.height * 0.42,
      )
      ..close();
    final coolPaint = Paint()
      ..color = palette.$2.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    final warmRibbon = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.78)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.60,
        size.width * 0.68,
        size.height * 0.96,
        size.width * 1.08,
        size.height * 0.72,
      )
      ..lineTo(size.width * 1.08, size.height * 1.12)
      ..lineTo(-size.width * 0.08, size.height * 1.12)
      ..close();
    final warmPaint = Paint()
      ..color = palette.$3.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);

    final glassSheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.03),
          V2DesignTokens.peacock.withValues(alpha: 0.07),
        ],
      ).createShader(Offset.zero & size);

    canvas
      ..drawRect(Offset.zero & size, wash)
      ..drawPath(coolRibbon, coolPaint)
      ..drawPath(warmRibbon, warmPaint)
      ..drawRect(Offset.zero & size, glassSheen);
  }

  @override
  bool shouldRepaint(covariant _LiquidBackdropPainter oldDelegate) {
    return oldDelegate.preset != preset;
  }
}

LinearGradient _backgroundGradient(String preset) {
  final palette = _backgroundPalette(preset);
  return LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      palette.$1.withValues(alpha: 0.38),
      palette.$3.withValues(alpha: 0.20),
      palette.$2.withValues(alpha: 0.30),
      V2DesignTokens.pearl,
    ],
    stops: const [0, 0.36, 0.74, 1],
  );
}

(Color, Color, Color) _backgroundPalette(String preset) {
  return switch (preset) {
    'sky' => (
      const Color(0xFF78D6F4),
      const Color(0xFF7E8EE8),
      const Color(0xFFEAF7FF),
    ),
    'blush' => (
      const Color(0xFFE9A7A0),
      const Color(0xFFB7A6F4),
      const Color(0xFFFFE8D9),
    ),
    'graphite' => (
      const Color(0xFF90A4AE),
      const Color(0xFF607D8B),
      const Color(0xFFECEFF1),
    ),
    _ => (V2DesignTokens.mint, V2DesignTokens.iris, V2DesignTokens.rose),
  };
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final List<(String, int, IconData)> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 112,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = metrics[index];
        return _GlassPane(
          enableBlur: false,
          child: Row(
            children: [
              Icon(item.$3, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _mutedInk),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Money(item.$2).format(),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TextMetricsGrid extends StatelessWidget {
  const _TextMetricsGrid({required this.metrics});
  final List<(String, String, IconData)> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 112,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = metrics[index];
        return _GlassPane(
          enableBlur: false,
          child: Row(
            children: [
              Icon(item.$3, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _mutedInk),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        item.$2,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
