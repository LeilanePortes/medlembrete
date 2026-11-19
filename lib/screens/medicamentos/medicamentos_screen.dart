import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../models/medicamento.dart';
import '../../services/dose_repository.dart';
import '../../services/medicamento_repository.dart';
import '../../services/notification_service.dart';
import '../../services/resumo_doses.dart';
import '../../widgets/placeholder_view.dart';
import '../dose/dose_screen.dart';
import 'medicamento_form_screen.dart';

/// Lista de remédios com seus lembretes diários.
class MedicamentosScreen extends StatelessWidget {
  const MedicamentosScreen({super.key});

  Future<void> _abrirFormulario(BuildContext context, [Medicamento? m]) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicamentoFormScreen(medicamento: m),
      ),
    );
  }

  Future<void> _testarNotificacao(BuildContext context, Medicamento m) async {
    final notificacoes = NotificationService.instance;
    // Na web, aproveita o clique para pedir a permissão, se faltar.
    if (notificacoes.precisaPermissaoWeb &&
        !await notificacoes.solicitarPermissoes()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notificações bloqueadas. Clique no cadeado ao lado '
              'do endereço do site e permita "Notificações".'),
        ),
      );
      return;
    }
    await notificacoes.agendarTeste(m);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notificação de teste em 10 segundos. '
          '${kIsWeb ? 'Pode minimizar o navegador, mas mantenha a aba aberta!' : 'Pode bloquear a tela ou sair do app!'}',
        ),
      ),
    );
  }

  Future<void> _alternarAtivo(Medicamento m, bool ativo) async {
    final atualizado = m.copyWith(ativo: ativo);
    await MedicamentoRepository.instance.salvar(atualizado);
    await NotificationService.instance.agendarLembretes(atualizado);
  }

  Future<void> _excluir(BuildContext context, Medicamento m) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir remédio?'),
        content: Text('Os lembretes de ${m.nome} serão cancelados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await NotificationService.instance.cancelarLembretes(m.id);
    await MedicamentoRepository.instance.remover(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final repositorio = MedicamentoRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus remédios'),
        actions: [
          IconButton(
            tooltip: 'Permitir notificações',
            icon: const Icon(Icons.notification_add_outlined),
            onPressed: () async {
              final ok = await NotificationService.instance.solicitarPermissoes();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Notificações permitidas ✅'
                      : kIsWeb
                          ? 'Notificações bloqueadas. Clique no cadeado ao '
                              'lado do endereço e permita "Notificações".'
                          : 'Notificações bloqueadas. Ative nas configurações.'),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: ListenableBuilder(
        // Redesenha quando muda um remédio OU quando uma dose é registrada.
        listenable: Listenable.merge([repositorio, DoseRepository.instance]),
        builder: (context, _) {
          final lista = repositorio.medicamentos;
          if (lista.isEmpty) {
            return const PlaceholderView(
              icon: Icons.medication_outlined,
              mensagem: 'Nenhum remédio cadastrado.\n'
                  'Toque em "Adicionar" para criar seu primeiro lembrete.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _MedicamentoTile(
              medicamento: lista[i],
              onEditar: () => _abrirFormulario(context, lista[i]),
              onTestar: () => _testarNotificacao(context, lista[i]),
              onExcluir: () => _excluir(context, lista[i]),
              onAtivo: (v) => _alternarAtivo(lista[i], v),
            ),
          );
        },
      ),
    );
  }
}

/// "Começa hoje às 22:00 · por 7 dias", "Até 25/11 (faltam 3 dias)",
/// "Tratamento concluído" ou null (uso contínuo já iniciado).
String? _situacao(Medicamento m, DateTime agora) {
  final inicio = m.inicio;
  if (inicio != null && inicio.isAfter(agora)) {
    final quando = mesmoDia(inicio, agora)
        ? 'hoje às ${formatarHora(inicio)}'
        : 'em ${formatarData(inicio).substring(0, 5)}';
    final duracao = m.continuo
        ? ''
        : ' · por ${m.duracaoDias} dia${m.duracaoDias == 1 ? '' : 's'}';
    return 'Começa $quando$duracao';
  }
  if (m.continuo) return null;
  if (m.encerrado(agora)) return 'Tratamento concluído';
  final ultima = m.ultimaOcorrencia!;
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final faltam =
      DateTime(ultima.year, ultima.month, ultima.day).difference(hoje).inDays;
  final quando = faltam == 0
      ? 'termina hoje'
      : 'falta${faltam == 1 ? '' : 'm'} $faltam dia${faltam == 1 ? '' : 's'}';
  return 'Até ${formatarData(ultima).substring(0, 5)} ($quando)';
}

class _MedicamentoTile extends StatelessWidget {
  const _MedicamentoTile({
    required this.medicamento,
    required this.onEditar,
    required this.onTestar,
    required this.onExcluir,
    required this.onAtivo,
  });

  final Medicamento medicamento;
  final VoidCallback onEditar;
  final VoidCallback onTestar;
  final VoidCallback onExcluir;
  final ValueChanged<bool> onAtivo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = medicamento;
    final agora = DateTime.now();
    final hojeDoRemedio = ResumoDoses.agendaDoDia(agora)
        .where((d) => d.medicamento.id == m.id)
        .toList();
    final tomadasHoje = hojeDoRemedio.where((d) => d.tomada).length;
    final tomadaHoje = DoseRepository.instance.tomadaHoje(m.id, agora);
    final situacao = _situacao(m, agora);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  m.horario,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: m.ativo ? scheme.primary : scheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.nome,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      if (m.dosagem.isNotEmpty)
                        Text(m.dosagem,
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      Text(
                        m.intervaloHoras == 24
                            ? m.descricaoDias
                            : '${m.descricaoFrequencia}: '
                                '${m.horariosDoDia.join(', ')}'
                                '${m.todaSemana ? '' : ' · ${m.descricaoDias}'}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      if (situacao != null)
                        Text(situacao,
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600)),
                      if (hojeDoRemedio.length > 1 && tomadasHoje > 0)
                        Text(
                          '✅ Hoje: $tomadasHoje de ${hojeDoRemedio.length} doses',
                          style: const TextStyle(
                            color: AppTheme.sucesso,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (tomadaHoje != null)
                        Text(
                          '✅ Tomado hoje às ${formatarHora(tomadaHoje.dataHora)}',
                          style: const TextStyle(
                            color: AppTheme.sucesso,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(value: m.ativo, onChanged: onAtivo),
              ],
            ),
            // Wrap evita estouro de largura em telas estreitas.
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DoseScreen(medicamento: m),
                    ),
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Tomar'),
                ),
                TextButton.icon(
                  onPressed: onTestar,
                  icon: const Icon(Icons.timer_10_outlined, size: 18),
                  label: const Text('Testar'),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: onExcluir,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
