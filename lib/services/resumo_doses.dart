import '../core/formatters.dart';
import '../models/dose.dart';
import '../models/dose_agendada.dart';
import '../models/medicamento.dart';
import 'dose_repository.dart';
import 'medicamento_repository.dart';

/// Cruza a agenda dos remédios com as doses comprovadas para saber
/// como está o dia.
class ResumoDoses {
  ResumoDoses._();

  /// Comprovante que cumpre a dose de [m] prevista para [horario].
  static Dose? comprovanteDe(Medicamento m, DateTime horario) {
    for (final d in DoseRepository.instance.doses) {
      if (d.medicamentoId != m.id) continue;
      final previsto = d.previstoPara;
      if (previsto != null) {
        if (previsto == horario) return d;
      } else if (mesmoDia(d.dataHora, horario) &&
          d.horarioPrevisto == formatarHora(horario)) {
        // Registro antigo, sem a data/hora exata prevista.
        return d;
      }
    }
    return null;
  }

  /// Todas as doses previstas hoje (remédios ativos), em ordem de horário.
  static List<DoseAgendada> agendaDoDia([DateTime? agora]) {
    final ref = agora ?? DateTime.now();
    final agenda = [
      for (final m in MedicamentoRepository.instance.medicamentos)
        if (m.ativo)
          for (final t in m.ocorrenciasNoDia(ref))
            DoseAgendada(m, t, comprovanteDe(m, t)),
    ]..sort((a, b) => a.horario.compareTo(b.horario));
    return agenda;
  }

  /// Doses de hoje cujo horário já passou e que ainda não foram comprovadas.
  static List<DoseAgendada> atrasadasHoje([DateTime? agora]) {
    final ref = agora ?? DateTime.now();
    return agendaDoDia(ref)
        .where((d) => !d.tomada && !d.horario.isAfter(ref))
        .toList();
  }

  /// Remédios com alguma dose atrasada hoje (sem repetir).
  static List<Medicamento> pendentesHoje([DateTime? agora]) {
    final vistos = <int>{};
    return [
      for (final d in atrasadasHoje(agora))
        if (vistos.add(d.medicamento.id)) d.medicamento,
    ];
  }

  /// (comprovadas, total) das doses de hoje.
  static (int, int) progressoHoje([DateTime? agora]) {
    final agenda = agendaDoDia(agora);
    return (agenda.where((d) => d.tomada).length, agenda.length);
  }

  /// Qual dose de [m] o usuário está comprovando agora: a dose ainda
  /// não tomada mais próxima de [agora] (das últimas 24 h até 2 h à
  /// frente). Se não houver, a próxima da agenda.
  static DateTime doseParaComprovar(Medicamento m, [DateTime? agora]) {
    final ref = agora ?? DateTime.now();
    final candidatas = m
        .ocorrenciasEntre(ref.subtract(const Duration(hours: 24)),
            ref.add(const Duration(hours: 2)))
        .where((t) => comprovanteDe(m, t) == null)
        .toList();
    if (candidatas.isEmpty) return m.proximaOcorrencia(ref) ?? ref;
    candidatas.sort((a, b) =>
        a.difference(ref).abs().compareTo(b.difference(ref).abs()));
    return candidatas.first;
  }
}
