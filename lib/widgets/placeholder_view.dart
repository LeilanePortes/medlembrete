import 'package:flutter/material.dart';

/// Tela provisória para funcionalidades ainda não implementadas.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({
    super.key,
    required this.icon,
    required this.mensagem,
  });

  final IconData icon;
  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
