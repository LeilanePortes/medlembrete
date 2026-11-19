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
        // Layout próprio (sem ListTile): o canto direito do ListTile tem
        // altura limitada e a hora + o dia empilhados estouravam 4 px.
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: const Icon(Icons.alarm),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Próxima dose',
                            style: Theme.of(context).textTheme.bodyLarge),
                        Text(
                          m == null
                              ? 'Nenhum lembrete ativo'
                              : '${m.nome}'
                                  '${m.dosagem.isEmpty ? '' : ' • ${m.dosagem}'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (proxima == null)
                    const Icon(Icons.chevron_right)
                  else
                    Column(
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
