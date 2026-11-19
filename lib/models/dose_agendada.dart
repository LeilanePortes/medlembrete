import 'dose.dart';
import 'medicamento.dart';

/// Uma dose prevista na agenda de um remédio (ex.: Amoxicilina às 16:00
/// de hoje) e, se já foi tomada, o comprovante correspondente.
class DoseAgendada {
  const DoseAgendada(this.medicamento, this.horario, [this.comprovante]);

  final Medicamento medicamento;
  final DateTime horario;
  final Dose? comprovante;

  bool get tomada => comprovante != null;
}
