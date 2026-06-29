import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

void main() {
  final outputs = <String, int>{
    'assets/brand/app_icon_16.png': 16,
    'assets/brand/app_icon_32.png': 32,
    'assets/brand/app_icon_48.png': 48,
    'assets/brand/app_icon_64.png': 64,
    'assets/brand/app_icon_128.png': 128,
    'assets/brand/app_icon_192.png': 192,
    'assets/brand/app_icon_256.png': 256,
    'assets/brand/app_icon_512.png': 512,
    'assets/brand/app_icon_1024.png': 1024,
    'web/favicon.png': 32,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-512.png': 512,
  };

  final pngCache = <int, Uint8List>{};
  for (final output in outputs.entries) {
    final png = pngCache.putIfAbsent(
      output.value,
      () => _renderPng(output.value),
    );
    final file = File(output.key)..parent.createSync(recursive: true);
    file.writeAsBytesSync(png);
  }

  final icoSizes = [16, 24, 32, 48, 64, 128, 256];
  final icoPngs = [
    for (final size in icoSizes)
      pngCache.putIfAbsent(size, () => _renderPng(size)),
  ];
  File('windows/runner/resources/app_icon.ico')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(_encodeIco(icoSizes, icoPngs));
}

Uint8List _renderPng(int size) {
  final pixels = Uint8List(size * size * 4);
  final canvas = _Canvas(pixels, size);
  final edge = 1.75 / size;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final px = (x + 0.5) / size;
      final py = (y + 0.5) / size;
      final cover = _roundedRect(px, py, 0.02, 0.02, 0.98, 0.98, 0.22, edge);
      if (cover <= 0) continue;

      final base = _mix(
        _mix(const _Color(247, 254, 255), const _Color(13, 129, 123), py),
        const _Color(16, 44, 68),
        (px * 0.34 + py * 0.18).clamp(0, 1).toDouble(),
      );
      final cyan = _radial(px, py, 0.24, 0.18, 0.62);
      final rose = _radial(px, py, 0.80, 0.18, 0.42);
      final color = _mix(
        _mix(base, const _Color(191, 255, 255), cyan * 0.46),
        const _Color(255, 184, 199),
        rose * 0.36,
      );
      canvas.setPixel(x, y, color.withAlpha(cover));
    }
  }

  canvas.roundedRect(
    0.18,
    0.16,
    0.82,
    0.84,
    0.16,
    const _Color(255, 255, 255),
    0.24,
  );
  canvas.strokeRoundedRect(
    0.18,
    0.16,
    0.82,
    0.84,
    0.16,
    const _Color(255, 255, 255),
    0.74,
    0.007,
  );
  canvas.line(0.24, 0.20, 0.76, 0.30, const _Color(255, 255, 255), 0.70, 0.014);
  canvas.line(0.23, 0.78, 0.78, 0.77, const _Color(128, 255, 255), 0.36, 0.010);

  canvas.shadowedRoundedRect(
    0.29,
    0.25,
    0.71,
    0.76,
    0.060,
    const _Color(228, 250, 247),
  );
  canvas.roundedRect(
    0.29,
    0.25,
    0.71,
    0.39,
    0.060,
    const _Color(13, 129, 123),
    1,
  );
  canvas.circle(0.59, 0.32, 0.040, const _Color(233, 255, 251), 1);
  canvas.circle(0.59, 0.32, 0.019, const _Color(13, 129, 123), 1);
  canvas.roundedRect(
    0.35,
    0.305,
    0.50,
    0.330,
    0.012,
    const _Color(233, 255, 251),
    0.95,
  );
  canvas.roundedRect(
    0.35,
    0.445,
    0.66,
    0.473,
    0.014,
    const _Color(143, 217, 211),
    0.55,
  );
  canvas.roundedRect(
    0.35,
    0.510,
    0.60,
    0.538,
    0.014,
    const _Color(143, 217, 211),
    0.42,
  );

  final bars = [
    (0.355, 0.602, 0.377, 0.690),
    (0.395, 0.578, 0.429, 0.690),
    (0.449, 0.615, 0.467, 0.690),
    (0.489, 0.568, 0.531, 0.690),
    (0.551, 0.594, 0.579, 0.690),
    (0.600, 0.552, 0.646, 0.690),
  ];
  for (final bar in bars) {
    canvas.roundedRect(
      bar.$1,
      bar.$2,
      bar.$3,
      bar.$4,
      0.008,
      const _Color(10, 98, 94),
      1,
    );
  }

  canvas.line(0.31, 0.26, 0.68, 0.27, const _Color(255, 255, 255), 0.45, 0.007);
  canvas.line(0.24, 0.18, 0.19, 0.52, const _Color(255, 255, 255), 0.44, 0.010);

  return _encodePng(size, size, pixels);
}

Uint8List _encodePng(int width, int height, Uint8List rgba) {
  final scanlines = BytesBuilder();
  for (var y = 0; y < height; y++) {
    scanlines.addByte(0);
    scanlines.add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }

  final bytes = BytesBuilder();
  bytes.add(_pngSignature);
  bytes.add(_chunk('IHDR', _u32(width) + _u32(height) + [8, 6, 0, 0, 0]));
  bytes.add(_chunk('IDAT', ZLibCodec(level: 9).encode(scanlines.takeBytes())));
  bytes.add(_chunk('IEND', const []));
  return bytes.takeBytes();
}

Uint8List _encodeIco(List<int> sizes, List<Uint8List> pngs) {
  final count = sizes.length;
  var offset = 6 + count * 16;
  final bytes = BytesBuilder();
  bytes.add([0, 0, 1, 0, count & 0xff, count >> 8]);

  for (var i = 0; i < count; i++) {
    final size = sizes[i];
    final png = pngs[i];
    bytes.add([
      size == 256 ? 0 : size,
      size == 256 ? 0 : size,
      0,
      0,
      1,
      0,
      32,
      0,
      ..._le32(png.length),
      ..._le32(offset),
    ]);
    offset += png.length;
  }

  for (final png in pngs) {
    bytes.add(png);
  }
  return bytes.takeBytes();
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  return [
    ..._u32(data.length),
    ...typeBytes,
    ...data,
    ..._u32(_crc32([...typeBytes, ...data])),
  ];
}

List<int> _u32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

List<int> _le32(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

double _roundedRect(
  double x,
  double y,
  double left,
  double top,
  double right,
  double bottom,
  double radius,
  double edge,
) {
  final cx = (left + right) / 2;
  final cy = (top + bottom) / 2;
  final hx = (right - left) / 2 - radius;
  final hy = (bottom - top) / 2 - radius;
  final qx = (x - cx).abs() - hx;
  final qy = (y - cy).abs() - hy;
  final outside = sqrt(max(qx, 0) * max(qx, 0) + max(qy, 0) * max(qy, 0));
  final inside = min(max(qx, qy), 0);
  final distance = outside + inside - radius;
  return (0.5 - distance / edge).clamp(0, 1).toDouble();
}

double _radial(double x, double y, double cx, double cy, double radius) {
  final distance = sqrt(pow(x - cx, 2) + pow(y - cy, 2));
  return (1 - distance / radius).clamp(0, 1).toDouble();
}

_Color _mix(_Color a, _Color b, double t) {
  final amount = t.clamp(0, 1).toDouble();
  return _Color(
    (a.r + (b.r - a.r) * amount).round(),
    (a.g + (b.g - a.g) * amount).round(),
    (a.b + (b.b - a.b) * amount).round(),
    a.a + (b.a - a.a) * amount,
  );
}

class _Canvas {
  _Canvas(this.pixels, this.size);

  final Uint8List pixels;
  final int size;

  void setPixel(int x, int y, _Color color) {
    _blendAt((y * size + x) * 4, color);
  }

  void roundedRect(
    double left,
    double top,
    double right,
    double bottom,
    double radius,
    _Color color,
    double alpha,
  ) {
    final minX = max(0, (left * size).floor() - 2);
    final maxX = min(size - 1, (right * size).ceil() + 2);
    final minY = max(0, (top * size).floor() - 2);
    final maxY = min(size - 1, (bottom * size).ceil() + 2);
    final edge = 1.5 / size;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final px = (x + 0.5) / size;
        final py = (y + 0.5) / size;
        final cover = _roundedRect(
          px,
          py,
          left,
          top,
          right,
          bottom,
          radius,
          edge,
        );
        if (cover > 0) {
          _blendAt((y * size + x) * 4, color.withAlpha(alpha * cover));
        }
      }
    }
  }

  void shadowedRoundedRect(
    double left,
    double top,
    double right,
    double bottom,
    double radius,
    _Color color,
  ) {
    roundedRect(
      left + 0.018,
      top + 0.032,
      right + 0.018,
      bottom + 0.032,
      radius,
      const _Color(0, 58, 61),
      0.22,
    );
    roundedRect(left, top, right, bottom, radius, color, 1);
  }

  void strokeRoundedRect(
    double left,
    double top,
    double right,
    double bottom,
    double radius,
    _Color color,
    double alpha,
    double width,
  ) {
    final minX = max(0, (left * size).floor() - 3);
    final maxX = min(size - 1, (right * size).ceil() + 3);
    final minY = max(0, (top * size).floor() - 3);
    final maxY = min(size - 1, (bottom * size).ceil() + 3);
    final edge = 1.4 / size;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final px = (x + 0.5) / size;
        final py = (y + 0.5) / size;
        final outer = _roundedRect(
          px,
          py,
          left,
          top,
          right,
          bottom,
          radius,
          edge,
        );
        final inner = _roundedRect(
          px,
          py,
          left + width,
          top + width,
          right - width,
          bottom - width,
          max(0, radius - width),
          edge,
        );
        final cover = (outer - inner).clamp(0, 1).toDouble();
        if (cover > 0) {
          _blendAt((y * size + x) * 4, color.withAlpha(alpha * cover));
        }
      }
    }
  }

  void circle(double cx, double cy, double radius, _Color color, double alpha) {
    final minX = max(0, ((cx - radius) * size).floor() - 2);
    final maxX = min(size - 1, ((cx + radius) * size).ceil() + 2);
    final minY = max(0, ((cy - radius) * size).floor() - 2);
    final maxY = min(size - 1, ((cy + radius) * size).ceil() + 2);
    final edge = 1.5 / size;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final px = (x + 0.5) / size;
        final py = (y + 0.5) / size;
        final distance = sqrt(pow(px - cx, 2) + pow(py - cy, 2));
        final cover = (0.5 - (distance - radius) / edge).clamp(0, 1).toDouble();
        if (cover > 0) {
          _blendAt((y * size + x) * 4, color.withAlpha(alpha * cover));
        }
      }
    }
  }

  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    _Color color,
    double alpha,
    double width,
  ) {
    final minX = max(0, (min(x1, x2) * size).floor() - 4);
    final maxX = min(size - 1, (max(x1, x2) * size).ceil() + 4);
    final minY = max(0, (min(y1, y2) * size).floor() - 4);
    final maxY = min(size - 1, (max(y1, y2) * size).ceil() + 4);
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len2 = dx * dx + dy * dy;
    final edge = 1.5 / size;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final px = (x + 0.5) / size;
        final py = (y + 0.5) / size;
        final t = (((px - x1) * dx + (py - y1) * dy) / len2)
            .clamp(0, 1)
            .toDouble();
        final lx = x1 + dx * t;
        final ly = y1 + dy * t;
        final distance = sqrt(pow(px - lx, 2) + pow(py - ly, 2));
        final cover = (0.5 - (distance - width / 2) / edge)
            .clamp(0, 1)
            .toDouble();
        if (cover > 0) {
          _blendAt((y * size + x) * 4, color.withAlpha(alpha * cover));
        }
      }
    }
  }

  void _blendAt(int index, _Color src) {
    final alpha = src.a.clamp(0, 1).toDouble();
    final inv = 1 - alpha;
    pixels[index] = (src.r * alpha + pixels[index] * inv).round();
    pixels[index + 1] = (src.g * alpha + pixels[index + 1] * inv).round();
    pixels[index + 2] = (src.b * alpha + pixels[index + 2] * inv).round();
    pixels[index + 3] = ((alpha + (pixels[index + 3] / 255) * inv) * 255)
        .round();
  }
}

class _Color {
  const _Color(this.r, this.g, this.b, [this.a = 1]);

  final int r;
  final int g;
  final int b;
  final double a;

  _Color withAlpha(double alpha) => _Color(r, g, b, a * alpha);
}
