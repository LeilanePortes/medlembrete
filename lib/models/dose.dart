import '../services/detector_movimento.dart';

/// Registro (comprovante) de que uma dose foi tomada.
///
/// Junta os quatro recursos do app: notificação (horário previsto),
/// câmera (foto), GPS (onde estava) e acelerômetro (estado do celular).
class Dose {
  const Dose({
    required this.id,
    required this.medicamentoId,
    required this.nomeMedicamento,
    required this.dosagem,
    required this.horarioPrevisto,
    required this.dataHora,
    required this.fotoPath,
    this.previstoPara,
    this.unidadesDescontadas,
    this.latitude,
    this.longitude,
    this.emCasa,
    this.distanciaCasaMetros,
    this.estadoCelular,
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

  /// Dose da agenda que este comprovante cumpre (dia + horário).
  /// null em registros antigos: aí vale o dia de [dataHora] + [horarioPrevisto].
  final DateTime? previstoPara;

  /// Unidades tiradas do estoque por esta dose (devolvidas se o
  /// comprovante for excluído). null = estoque não controlado.
  final int? unidadesDescontadas;

  /// Caminho da foto de comprovação salva no armazenamento do app.
  final String fotoPath;

  /// Coordenadas no momento da confirmação (null se o GPS falhou).
  final double? latitude;
  final double? longitude;

  /// true = em casa, false = fora, null = casa não definida / sem GPS.
  final bool? emCasa;
  final double? distanciaCasaMetros;

  /// Estado do celular segundo o acelerômetro no momento da confirmação.
  final EstadoMovimento? estadoCelular;

  bool get temLocalizacao => latitude != null && longitude != null;

  String get descricaoLocal => switch (emCasa) {
        true => 'Em casa',
        false => 'Fora de casa',
        null => temLocalizacao ? 'Casa não definida' : 'Sem localização',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicamentoId': medicamentoId,
        'nomeMedicamento': nomeMedicamento,
        'dosagem': dosagem,
        'horarioPrevisto': horarioPrevisto,
        'dataHora': dataHora.toIso8601String(),
        'fotoPath': fotoPath,
        'previstoPara': previstoPara?.toIso8601String(),
        'unidadesDescontadas': unidadesDescontadas,
        'latitude': latitude,
        'longitude': longitude,
        'emCasa': emCasa,
        'distanciaCasaMetros': distanciaCasaMetros,
        'estadoCelular': estadoCelular?.name,
      };

  factory Dose.fromJson(Map<String, dynamic> json) {
    final estado = json['estadoCelular'] as String?;
    return Dose(
      id: json['id'] as int,
      medicamentoId: json['medicamentoId'] as int,
      nomeMedicamento: json['nomeMedicamento'] as String,
      dosagem: json['dosagem'] as String? ?? '',
      horarioPrevisto: json['horarioPrevisto'] as String? ?? '',
      dataHora: DateTime.parse(json['dataHora'] as String),
      fotoPath: json['fotoPath'] as String,
      previstoPara: json['previstoPara'] == null
          ? null
          : DateTime.parse(json['previstoPara'] as String),
      unidadesDescontadas: json['unidadesDescontadas'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      emCasa: json['emCasa'] as bool?,
      distanciaCasaMetros: (json['distanciaCasaMetros'] as num?)?.toDouble(),
      estadoCelular: estado == null
          ? null
          : EstadoMovimento.values.asNameMap()[estado],
    );
  }
}
