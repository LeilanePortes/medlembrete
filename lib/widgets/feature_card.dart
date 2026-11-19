import 'package:flutter/material.dart';

/// Cartão de atalho usado na tela inicial para cada funcionalidade.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.titulo,
    required this.descricao,
    required this.onTap,
    this.cor,
  });

  final IconData icon;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final corIcone = cor ?? scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: corIcone.withValues(alpha: 0.15),
                foregroundColor: corIcone,
                child: Icon(icon),
              ),
              const Spacer(),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
