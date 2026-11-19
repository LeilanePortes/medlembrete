import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/theme/app_theme.dart';
import '../services/detector_movimento.dart';
import '../services/dose_repository.dart';
import '../services/medicamento_repository.dart';
import '../services/movimento_service.dart';
import '../services/resumo_doses.dart';

/// Resumo do dia: progresso das doses e estado atual do celular.
class StatusHojeCard extends StatelessWidget {
  const StatusHojeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                MedicamentoRepository.instance,
                DoseRepository.instance,
              ]),
              builder: (context, _) {
                final (tomadas, total) = ResumoDoses.progressoHoje();
                final atrasadas = ResumoDoses.atrasadasHoje();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Hoje',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('$tomadas de $total doses comprovadas',
                              textAlign: TextAlign.end,
                              style:
                                  TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : tomadas / total,
                        minHeight: 10,
                      ),
                    ),
                    if (atrasadas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '⚠️ Atrasado: ${atrasadas.map((d) => '${d.medicamento.nome} (${formatarHora(d.horario)})').join(', ')}',
                        style: const TextStyle(
                          color: AppTheme.perigo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: MovimentoService.instance,
              builder: (context, _) {
                final movimento = MovimentoService.instance;
                final estado = movimento.estado;
                final cor = switch (estado) {
                  EstadoMovimento.emMovimento => AppTheme.sucesso,
                  EstadoMovimento.parado => AppTheme.alerta,
                  EstadoMovimento.esquecido => AppTheme.perigo,
                };
                return Row(
                  children: [
                    Icon(Icons.sensors, size: 18, color: cor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        movimento.ativo
                            ? 'Celular: ${estado.rotulo.toLowerCase()}'
                            : 'Acelerômetro pausado',
                        style:
                            TextStyle(color: cor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
