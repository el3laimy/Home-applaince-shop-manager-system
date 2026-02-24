import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Aesthetic Colors
  static const Color primaryColor = Color(0xFF6C63FF); 
  static const Color secondaryColor = Color(0xFF00E5FF); // Neon Cyan for accents
  static const Color bgDark = Color(0xFF0B0F19); // Super deep slate/navy
  static const Color surfaceDark = Color(0xFF131A2A); // Elevated surface
  
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.cairoTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: GoogleFonts.cairo(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shadowColor: primaryColor.withAlpha(30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceDark,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.cairo(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        elevation: 12,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: surfaceDark.withAlpha(200),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white.withAlpha(15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }
}
