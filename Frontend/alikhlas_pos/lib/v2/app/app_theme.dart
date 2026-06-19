import 'package:flutter/material.dart';

import 'design_tokens.dart';

ThemeData buildV2Theme() {
  const ink = V2DesignTokens.ink;
  const inkMuted = V2DesignTokens.inkMuted;

  final baseTextTheme = const TextTheme(
    displaySmall: TextStyle(
      color: ink,
      fontWeight: FontWeight.w700,
      fontSize: 34,
      height: 1.3,
    ),
    headlineLarge: TextStyle(
      color: ink,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      color: ink,
      fontWeight: FontWeight.w700,
      fontSize: 23,
      height: 1.32,
    ),
    headlineSmall: TextStyle(
      color: ink,
      fontWeight: FontWeight.w600,
      fontSize: 20,
      height: 1.35,
    ),
    titleLarge: TextStyle(
      color: ink,
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.38,
    ),
    titleMedium: TextStyle(
      color: ink,
      fontWeight: FontWeight.w600,
      fontSize: 16,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      color: ink,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.4,
    ),
    bodyLarge: TextStyle(
      color: ink,
      fontWeight: FontWeight.w400,
      fontSize: 15,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      color: ink,
      fontWeight: FontWeight.w400,
      fontSize: 14,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      color: inkMuted,
      fontWeight: FontWeight.w400,
      fontSize: 12,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      color: ink,
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.22,
    ),
    labelMedium: TextStyle(
      color: ink,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.22,
    ),
    labelSmall: TextStyle(
      color: inkMuted,
      fontWeight: FontWeight.w500,
      fontSize: 11,
      height: 1.2,
    ),
  ).apply(fontFamily: 'Cairo');

  final roundedFieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Cairo',
    colorScheme: ColorScheme.fromSeed(
      seedColor: V2DesignTokens.peacock,
      brightness: Brightness.light,
      surface: V2DesignTokens.pearl,
      primary: V2DesignTokens.peacock,
      secondary: V2DesignTokens.copper,
      tertiary: V2DesignTokens.mint,
    ),
    scaffoldBackgroundColor: V2DesignTokens.pearl,
    textTheme: baseTextTheme,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.86),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: roundedFieldBorder,
      enabledBorder: roundedFieldBorder,
      focusedBorder: roundedFieldBorder.copyWith(
        borderSide: const BorderSide(color: V2DesignTokens.peacock, width: 1.4),
      ),
      errorBorder: roundedFieldBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: roundedFieldBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
      ),
      labelStyle: const TextStyle(color: inkMuted),
      hintStyle: const TextStyle(color: inkMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        ),
        textStyle: baseTextTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: V2DesignTokens.peacockDeep,
        side: BorderSide(color: V2DesignTokens.peacock.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(V2DesignTokens.radiusMd),
        ),
        textStyle: baseTextTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: baseTextTheme.labelLarge),
    ),
    dividerTheme: DividerThemeData(
      color: V2DesignTokens.inkMuted.withValues(alpha: 0.16),
      thickness: 1,
      space: 1,
    ),
  );
}
