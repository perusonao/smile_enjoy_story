import 'package:flutter/material.dart';

/// S.E.S. theme: Blue / Cyan / White, kept intentionally plain — this is a
/// playable prototype, not a visual showcase (§5, §34).
class SesTheme {
  const SesTheme._();

  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color accentCyan = Color(0xFF00BCD4);
  static const Color background = Color(0xFFF5F9FC);

  static ThemeData build() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      secondary: accentCyan,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accentCyan.withValues(alpha: 0.25),
        elevation: 2,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Max content width so desktop web renders a phone-ish column, per §5.
const double phoneWidth = 430;

/// Formats an integer amount of yen as `¥1,234,567`.
String formatYen(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}¥$buffer';
}
