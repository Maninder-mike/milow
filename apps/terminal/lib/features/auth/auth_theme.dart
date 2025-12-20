import 'dart:math';
import 'package:flutter/material.dart';

class AuthTheme {
  final LinearGradient gradient;
  final Color primaryContentColor;
  final Color secondaryContentColor;
  final Color glassColor;
  final Color glassBorderColor;
  final Color inputFillColor;

  const AuthTheme({
    required this.gradient,
    required this.primaryContentColor,
    required this.secondaryContentColor,
    required this.glassColor,
    required this.glassBorderColor,
    required this.inputFillColor,
  });

  static final List<AuthTheme> themes = [
    // 1. Cyber Silver (Light) - Clean, metallic, futuristic
    AuthTheme(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE0E7FF),
          Color(0xFFF3E8FF),
        ], // Pale Indigo to Pale Purple
      ),
      primaryContentColor: const Color(0xFF18181B), // Zinc 900
      secondaryContentColor: const Color(0xFF52525B), // Zinc 600
      glassColor: const Color(0x66FFFFFF), // White with 40% opacity
      glassBorderColor: const Color(0x80FFFFFF), // White with 50% opacity
      inputFillColor: const Color(0x80FFFFFF), // White with 50% opacity
    ),
    // 2. Neon Mist (Light) - Airy cyan and teal
    AuthTheme(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFCCFBF1), Color(0xFFE0F2FE)], // Teal 100 to Sky 100
      ),
      primaryContentColor: const Color(0xFF0F172A), // Slate 900
      secondaryContentColor: const Color(0xFF475569), // Slate 600
      glassColor: const Color(0x66FFFFFF),
      glassBorderColor: const Color(0x80FFFFFF),
      inputFillColor: const Color(0x80FFFFFF),
    ),
    // 3. Soft Sunset (Light) - Warm, welcoming future
    AuthTheme(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFEDD5),
          Color(0xFFFFE4E6),
        ], // Orange 100 to Rose 100
      ),
      primaryContentColor: const Color(0xFF431407), // Warm Brown/Black
      secondaryContentColor: const Color(0xFF78350F), // Warm Brown
      glassColor: const Color(0x66FFFFFF),
      glassBorderColor: const Color(0x80FFFFFF),
      inputFillColor: const Color(0x80FFFFFF),
    ),
    // 4. Deep Space (Dark) - Classic futuristic fallback
    AuthTheme(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF312E81),
          Color(0xFF4C1D95),
        ], // Indigo 900 to Violet 900
      ),
      primaryContentColor: Colors.white,
      secondaryContentColor: const Color(0xB3FFFFFF), // White 70%
      glassColor: const Color(0x33000000), // Black 20%
      glassBorderColor: const Color(0x4DFFFFFF), // White 30%
      inputFillColor: const Color(0x1AFFFFFF), // White 10%
    ),
    // 5. Electric Violet (Medium) - Vibrant futuristic
    AuthTheme(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF818CF8),
          Color(0xFFC084FC),
        ], // Indigo 400 to Purple 400
      ),
      primaryContentColor: Colors.white,
      secondaryContentColor: const Color(0xE6FFFFFF), // White 90%
      glassColor: const Color(0x33FFFFFF),
      glassBorderColor: const Color(0x66FFFFFF),
      inputFillColor: const Color(0x33FFFFFF),
    ),
  ];

  static AuthTheme getRandom() {
    return themes[Random().nextInt(themes.length)];
  }
}
