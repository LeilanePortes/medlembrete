import '../models/medicamento.dart';
import 'dose_repository.dart';
import 'medicamento_repository.dart';

/// Cruza remédios e doses registradas para saber como está o dia.
class ResumoDoses {
  ResumoDoses._();

  /// Remédios ativos cujo horário de hoje já passou e que ainda
  /// não foram comprovados.
  static List<Medicamento> pendentesHoje([DateTime? agora]) {
    final ref = agora ?? DateTime.now();
    final minutosAgora = ref.hour * 60 + ref.minute;
    return MedicamentoRepository.instance.medicamentos
        .where((m) =>
            m.ativo &&
            m.hora * 60 + m.minuto <= minutosAgora &&
            DoseRepository.instance.tomadaHoje(m.id, ref) == null)
        .toList();
  }

  /// (comprovadas, total) dos remédios ativos de hoje.
  static (int, int) progressoHoje([DateTime? agora]) {
    final ref = agora ?? DateTime.now();
    final ativos =
        MedicamentoRepository.instance.medicamentos.where((m) => m.ativo);
    final tomadas = ativos
        .where((m) => DoseRepository.instance.tomadaHoje(m.id, ref) != null)
        .length;
    return (tomadas, ativos.length);
  }
}
