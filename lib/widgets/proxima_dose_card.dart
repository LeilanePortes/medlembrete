import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../services/medicamento_repository.dart';

/// Mostra o próximo remédio a ser tomado (atualiza sozinho).
class ProximaDoseCard extends StatelessWidget {
  const ProximaDoseCard({super.key, required this.onTap});

  final VoidCallback onTap;

  /// "Hoje", "Amanhã" ou "25/11".
  static String rotuloDia(DateTime horario, [DateTime? agora]) {
    final hoje = agora ?? DateTime.now();
    if (mesmoDia(horario, hoje)) return 'Hoje';
    if (mesmoDia(horario, DateTime(hoje.year, hoje.month, hoje.day + 1))) {
      return 'Amanhã';
    }
    return formatarData(horario).substring(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final repositorio = MedicamentoRepository.instance;

    return ListenableBuilder(
      listenable: repositorio,
      builder: (context, _) {
        final proxima = repositorio.proximaDose();
        final m = proxima?.medicamento;
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
              m == null
                  ? 'Nenhum lembrete ativo'
                  : '${m.nome}${m.dosagem.isEmpty ? '' : ' • ${m.dosagem}'}',
            ),
            trailing: proxima == null
                ? const Icon(Icons.chevron_right)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatarHora(proxima.horario),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        rotuloDia(proxima.horario),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
