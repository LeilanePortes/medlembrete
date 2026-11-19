import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../models/medicamento.dart';
import '../../services/medicamento_repository.dart';
import '../../services/notification_service.dart';

/// Cadastro / edição de um remédio e da sua agenda de doses:
/// data de início, horário da 1ª dose, frequência, dias da semana
/// e duração do tratamento.
class MedicamentoFormScreen extends StatefulWidget {
  const MedicamentoFormScreen({super.key, this.medicamento});

  /// Quando informado, a tela edita este remédio.
  final Medicamento? medicamento;

  @override
  State<MedicamentoFormScreen> createState() => _MedicamentoFormScreenState();
}

class _MedicamentoFormScreenState extends State<MedicamentoFormScreen> {
  static const List<int> _sugestoesDias = [5, 7, 10, 14, 30];

  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _dosagem;
  late final TextEditingController _dias;
  late DateTime _dataInicio;
  late TimeOfDay _horario;
  late int _intervalo;
  late Set<int> _diasSemana;
  late bool _continuo;
  bool _salvando = false;

  bool get _editando => widget.medicamento != null;

  @override
  void initState() {
    super.initState();
    final m = widget.medicamento;
    final agora = DateTime.now();
    _nome = TextEditingController(text: m?.nome ?? '');
    _dosagem = TextEditingController(text: m?.dosagem ?? '');
    _dias = TextEditingController(text: '${m?.duracaoDias ?? 7}');
    _dataInicio = m?.dataInicio ?? DateTime(agora.year, agora.month, agora.day);
    _horario = m != null
        ? TimeOfDay(hour: m.hora, minute: m.minuto)
        // Sugere 2 minutos à frente: facilita testar o lembrete real.
        : TimeOfDay.fromDateTime(agora.add(const Duration(minutes: 2)));
    _intervalo = m?.intervaloHoras ?? 24;
    _diasSemana = {...(m?.diasSemana ?? Medicamento.todosOsDias)};
    _continuo = m == null || m.duracaoDias == null;
  }

  @override
  void dispose() {
    _nome.dispose();
    _dosagem.dispose();
    _dias.dispose();
    super.dispose();
  }

  int? get _duracaoDias {
    if (_continuo) return null;
    final n = int.tryParse(_dias.text.trim());
    return (n == null || n < 1 || n > 365) ? null : n;
  }

  /// Remédio com os valores atuais da tela (para a prévia e para salvar).
  Medicamento _montar() {
    final base = widget.medicamento;
    return Medicamento(
      id: base?.id ?? Medicamento.novoId(),
      nome: _nome.text.trim(),
      dosagem: _dosagem.text.trim(),
      hora: _horario.hour,
      minuto: _horario.minute,
      ativo: base?.ativo ?? true,
      dataInicio: _dataInicio,
      intervaloHoras: _intervalo,
      diasSemana: {..._diasSemana},
      duracaoDias: _duracaoDias,
    );
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(hoje.year - 1, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'Início do tratamento',
    );
    if (escolhida != null) setState(() => _dataInicio = escolhida);
  }

  Future<void> _escolherHorario() async {
    final escolhido = await showTimePicker(
      context: context,
      initialTime: _horario,
      helpText: 'Horário da 1ª dose',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (escolhido != null) setState(() => _horario = escolhido);
  }

  void _alternarDia(int dia, bool marcado) {
    // Pelo menos um dia precisa ficar marcado.
    if (!marcado && _diasSemana.length == 1) return;
    setState(() => marcado ? _diasSemana.add(dia) : _diasSemana.remove(dia));
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    final medicamento = _montar();

    if (!medicamento.continuo &&
        medicamento.ocorrenciasEntre(medicamento.inicio!, medicamento.fim!)
            .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma dose cai nesse período. '
              'Confira os dias da semana e a duração.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    await MedicamentoRepository.instance.salvar(medicamento);
    await NotificationService.instance.agendarLembretes(medicamento);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lembretes de ${medicamento.nome} agendados: '
          '${medicamento.horariosDoDia.join(', ')} '
          '(${medicamento.descricaoDias.toLowerCase()}).',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titulo = Theme.of(context).textTheme.titleMedium;
    final hoje = DateTime.now();
    final horario =
        '${_horario.hour.toString().padLeft(2, '0')}:${_horario.minute.toString().padLeft(2, '0')}';
    final previa = _montar();

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
                hintText: 'Ex.: Amoxicilina',
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
                hintText: 'Ex.: 1 comprimido de 500 mg',
                prefixIcon: Icon(Icons.scale),
              ),
            ),
            const SizedBox(height: 24),

            // ---------------- Quando começa ----------------
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.event, color: scheme.primary),
                    title: const Text('Início'),
                    subtitle: Text(mesmoDia(_dataInicio, hoje)
                        ? 'Hoje'
                        : 'Toque para alterar'),
                    trailing: Text(
                      formatarData(_dataInicio),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    onTap: _escolherData,
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  ListTile(
                    leading: Icon(Icons.alarm, color: scheme.primary),
                    title: const Text('1ª dose do dia'),
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
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ---------------- Frequência ----------------
            Text('Frequência', style: titulo),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in Medicamento.intervalosPermitidos.reversed)
                  ChoiceChip(
                    label: Text(Medicamento.descreverIntervalo(h)),
                    selected: _intervalo == h,
                    onSelected: (_) => setState(() => _intervalo = h),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Horários: ${previa.horariosDoDia.join(' · ')}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // ---------------- Dias da semana ----------------
            Row(
              children: [
                Expanded(child: Text('Dias da semana', style: titulo)),
                TextButton(
                  onPressed: _diasSemana.length == 7
                      ? null
                      : () => setState(() =>
                          _diasSemana = {...Medicamento.todosOsDias}),
                  child: const Text('Todos'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(Medicamento.nomesDias[d - 1]),
                    selected: _diasSemana.contains(d),
                    showCheckmark: false,
                    onSelected: (v) => _alternarDia(d, v),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ---------------- Duração ----------------
            Text('Duração', style: titulo),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.all_inclusive),
                  label: Text('Uso contínuo'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.date_range),
                  label: Text('Por um período'),
                ),
              ],
              selected: {_continuo},
              onSelectionChanged: (s) => setState(() => _continuo = s.first),
            ),
            if (!_continuo) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _dias,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Quantos dias?',
                  suffixText: 'dias',
                  prefixIcon: Icon(Icons.timelapse),
                ),
                onChanged: (_) => setState(() {}),
                validator: (_) => _duracaoDias == null
                    ? 'Informe de 1 a 365 dias'
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in _sugestoesDias)
                    ActionChip(
                      label: Text('$n dias'),
                      onPressed: () => setState(() => _dias.text = '$n'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _ResumoAgenda(medicamento: previa),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Salvar e agendar lembretes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumo em texto da agenda que será criada.
class _ResumoAgenda extends StatelessWidget {
  const _ResumoAgenda({required this.medicamento});

  final Medicamento medicamento;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = medicamento;
    final primeira = m.proximaOcorrencia(
        m.inicio!.subtract(const Duration(minutes: 1)));

    final linhas = <String>[
      '${m.descricaoFrequencia} · ${m.descricaoDias.toLowerCase()}',
      if (primeira != null) '1ª dose: ${formatarDataHora(primeira)}',
    ];
    if (m.continuo) {
      linhas.add('Uso contínuo (sem data para acabar)');
    } else {
      final ultima = m.ultimaOcorrencia;
      final total = m.ocorrenciasEntre(m.inicio!, m.fim!).length;
      if (ultima != null) linhas.add('Última dose: ${formatarDataHora(ultima)}');
      linhas.add('$total ${total == 1 ? 'dose' : 'doses'} no total');
    }

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.event_note, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumo da agenda',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final l in linhas)
                    Text(l,
                        style: TextStyle(color: scheme.onSecondaryContainer)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
