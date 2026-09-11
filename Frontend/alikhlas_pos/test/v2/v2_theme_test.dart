import 'dart:io';

import 'package:alikhlas_pos/v2/app/app_theme.dart';
import 'package:alikhlas_pos/v2/app/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme uses bundled Cairo font family', () {
    final theme = buildV2Theme();

    expect(theme.textTheme.bodyMedium?.fontFamily, 'Cairo');
    expect(theme.textTheme.titleMedium?.fontFamily, 'Cairo');
    expect(theme.textTheme.labelLarge?.fontFamily, 'Cairo');
  });

  test('body text keeps WCAG AA contrast over glass surface', () {
    final glassOverPearl = Color.alphaBlend(
      V2DesignTokens.glassWhite,
      V2DesignTokens.pearl,
    );

    expect(
      _contrastRatio(V2DesignTokens.ink, glassOverPearl),
      greaterThan(4.5),
    );
  });

  test('v2 ui avoids disallowed typography and icon regressions', () {
    final v2Source = _readTree(Directory('lib/v2'));
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(v2Source, isNot(contains("fontFamily: 'Roboto'")));
    expect(v2Source, isNot(contains('FontWeight.w800')));
    expect(v2Source, isNot(contains('Cairo-ExtraBold')));
    if (!pubspec.contains('cupertino_icons:')) {
      expect(v2Source, isNot(contains('CupertinoIcons')));
    }
  });

  test('liquid glass keeps real blur centralized and opt-in', () {
    final appSource = _readTree(Directory('lib/v2/app'));

    expect(RegExp(r'BackdropFilter\(').allMatches(appSource), hasLength(1));
    expect(appSource, contains('this.enableBlur = false'));
  });
}

String _readTree(Directory directory) {
  final buffer = StringBuffer();
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    buffer.writeln(entity.readAsStringSync());
  }
  return buffer.toString();
}

double _contrastRatio(Color foreground, Color background) {
  final light = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final dark = identical(light, foreground) ? background : foreground;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}
