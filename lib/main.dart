import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/dashboard/dashboard_page.dart';

void main() {
  runApp(const CopilotoApp());
}

/// Raiz do app. Escuta AppTheme.themeMode para trocar o tema em tempo real.
class CopilotoApp extends StatelessWidget {
  const CopilotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Copiloto Auto',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const DashboardPage(),
        );
      },
    );
  }
}
