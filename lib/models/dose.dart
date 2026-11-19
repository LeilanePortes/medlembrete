/// Registro (comprovante) de que uma dose foi tomada.
class Dose {
  const Dose({
    required this.id,
    required this.medicamentoId,
    required this.nomeMedicamento,
    required this.dosagem,
    required this.horarioPrevisto,
    required this.dataHora,
    required this.fotoPath,
  });

  final int id;
  final int medicamentoId;

  /// Copiados do remédio para o histórico continuar legível
  /// mesmo se o remédio for editado ou excluído.
  final String nomeMedicamento;
  final String dosagem;

  /// Horário programado do lembrete, ex.: "08:00".
  final String horarioPrevisto;

  /// Momento real em que a dose foi confirmada.
  final DateTime dataHora;

  /// Caminho da foto de comprovação salva no armazenamento do app.
  final String fotoPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicamentoId': medicamentoId,
        'nomeMedicamento': nomeMedicamento,
        'dosagem': dosagem,
        'horarioPrevisto': horarioPrevisto,
        'dataHora': dataHora.toIso8601String(),
        'fotoPath': fotoPath,
      };

  factory Dose.fromJson(Map<String, dynamic> json) => Dose(
        id: json['id'] as int,
        medicamentoId: json['medicamentoId'] as int,
        nomeMedicamento: json['nomeMedicamento'] as String,
        dosagem: json['dosagem'] as String? ?? '',
        horarioPrevisto: json['horarioPrevisto'] as String? ?? '',
        dataHora: DateTime.parse(json['dataHora'] as String),
        fotoPath: json['fotoPath'] as String,
      );
}
