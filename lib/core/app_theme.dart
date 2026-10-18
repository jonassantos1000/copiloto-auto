import 'package:flutter/material.dart';

/// Tema centralizado do app: cores, formas e modo claro/escuro.
class AppTheme {
  static const primary = Color(0xFF4F46E5);
  static const lightBackground = Color(0xFFF4F6FB);
  static const darkBackground = Color(0xFF0F172A);
  static const darkCard = Color(0xFF1E293B);

  /// Modo atual do app (sistema, claro ou escuro). O botão da dashboard altera este valor.
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: lightBackground,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
    );
  }

  /// Decoração padrão dos cartões. Muda sozinha entre claro e escuro.
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkCard : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
    );
  }
}
