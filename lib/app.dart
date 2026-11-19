import 'package:flutter/material.dart';

import 'core/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'screens/shell/main_shell.dart';

/// Chave global do Navigator: permite navegar a partir de serviços
/// (ex.: quando o usuário toca em uma notificação).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MedLembreteApp extends StatelessWidget {
  const MedLembreteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const MainShell(),
    );
  }
}
