import 'package:flutter/material.dart';

import '../../models/medicamento.dart';
import '../../services/medicamento_repository.dart';
import '../../services/notification_service.dart';
import '../../widgets/placeholder_view.dart';
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
    await NotificationService.instance.agendarTeste(m);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notificação de teste em 10 segundos. '
          'Pode bloquear a tela ou sair do app!',
        ),
      ),
    );
  }

  Future<void> _alternarAtivo(Medicamento m, bool ativo) async {
    final atualizado = m.copyWith(ativo: ativo);
    await MedicamentoRepository.instance.salvar(atualizado);
    await NotificationService.instance.agendarLembreteDiario(atualizado);
  }

  Future<void> _excluir(BuildContext context, Medicamento m) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir remédio?'),
        content: Text('O lembrete de ${m.nome} será cancelado.'),
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
    await NotificationService.instance.cancelar(m.id);
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
        listenable: repositorio,
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
                    ],
                  ),
                ),
                Switch(value: m.ativo, onChanged: onAtivo),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
