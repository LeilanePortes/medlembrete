import 'package:flutter/material.dart';

import '../services/medicamento_repository.dart';

/// Mostra o próximo remédio a ser tomado (atualiza sozinho).
class ProximaDoseCard extends StatelessWidget {
  const ProximaDoseCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repositorio = MedicamentoRepository.instance;

    return ListenableBuilder(
      listenable: repositorio,
      builder: (context, _) {
        final proximo = repositorio.proximaDose();
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: onTap,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.alarm),
            ),
            title: const Text('Próxima dose'),
            subtitle: Text(
              proximo == null
                  ? 'Nenhum lembrete ativo'
                  : '${proximo.nome}'
                      '${proximo.dosagem.isEmpty ? '' : ' • ${proximo.dosagem}'}',
            ),
            trailing: proximo == null
                ? const Icon(Icons.chevron_right)
                : Text(
                    proximo.horario,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
