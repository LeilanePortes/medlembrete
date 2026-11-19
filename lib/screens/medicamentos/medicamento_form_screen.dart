import 'package:flutter/material.dart';

import '../../models/medicamento.dart';
import '../../services/medicamento_repository.dart';
import '../../services/notification_service.dart';

/// Cadastro / edição de um remédio e do horário do lembrete.
class MedicamentoFormScreen extends StatefulWidget {
  const MedicamentoFormScreen({super.key, this.medicamento});

  /// Quando informado, a tela edita este remédio.
  final Medicamento? medicamento;

  @override
  State<MedicamentoFormScreen> createState() => _MedicamentoFormScreenState();
}

class _MedicamentoFormScreenState extends State<MedicamentoFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _dosagem;
  late TimeOfDay _horario;
  bool _salvando = false;

  bool get _editando => widget.medicamento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicamento;
    _nome = TextEditingController(text: m?.nome ?? '');
    _dosagem = TextEditingController(text: m?.dosagem ?? '');
    final agora = TimeOfDay.now();
    _horario = m != null
        ? TimeOfDay(hour: m.hora, minute: m.minuto)
        // Sugere 2 minutos à frente: facilita testar o lembrete real.
        : TimeOfDay(
            hour: (agora.hour + (agora.minute + 2) ~/ 60) % 24,
            minute: (agora.minute + 2) % 60,
          );
  }

  @override
  void dispose() {
    _nome.dispose();
    _dosagem.dispose();
    super.dispose();
  }

  Future<void> _escolherHorario() async {
    final escolhido = await showTimePicker(
      context: context,
      initialTime: _horario,
      helpText: 'Horário do lembrete',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (escolhido != null) setState(() => _horario = escolhido);
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);

    final base = widget.medicamento;
    final medicamento = (base ??
            Medicamento(
              id: Medicamento.novoId(),
              nome: '',
              dosagem: '',
              hora: 0,
              minuto: 0,
            ))
        .copyWith(
      nome: _nome.text.trim(),
      dosagem: _dosagem.text.trim(),
      hora: _horario.hour,
      minuto: _horario.minute,
    );

    await MedicamentoRepository.instance.salvar(medicamento);
    await NotificationService.instance.agendarLembreteDiario(medicamento);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lembrete de ${medicamento.nome} agendado para '
          '${medicamento.horario} todos os dias.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final horario =
        '${_horario.hour.toString().padLeft(2, '0')}:${_horario.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar remédio' : 'Novo remédio'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome do remédio',
                hintText: 'Ex.: Losartana',
                prefixIcon: Icon(Icons.medication),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dosagem,
              decoration: const InputDecoration(
                labelText: 'Dosagem (opcional)',
                hintText: 'Ex.: 1 comprimido de 50 mg',
                prefixIcon: Icon(Icons.scale),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(Icons.alarm, color: scheme.primary),
                title: const Text('Horário diário'),
                subtitle: const Text('Toque para alterar'),
                trailing: Text(
                  horario,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                onTap: _escolherHorario,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Salvar e agendar lembrete'),
            ),
          ],
        ),
      ),
    );
  }
}
