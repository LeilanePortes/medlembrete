/// Um remédio cadastrado pelo usuário, com o horário diário do lembrete.
class Medicamento {
  const Medicamento({
    required this.id,
    required this.nome,
    required this.dosagem,
    required this.hora,
    required this.minuto,
    this.ativo = true,
  });

  /// Identificador único. Também é usado como ID da notificação agendada.
  final int id;
  final String nome;

  /// Ex.: "1 comprimido", "500 mg", "10 gotas".
  final String dosagem;
  final int hora;
  final int minuto;

  /// Quando falso, o lembrete diário fica desligado.
  final bool ativo;

  /// Gera um ID inteiro de 31 bits (limite das notificações no Android).
  static int novoId() =>
      DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);

  String get horario =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  /// Próxima ocorrência do horário do remédio a partir de [agora].
  DateTime proximaOcorrencia([DateTime? agora]) {
    final ref = agora ?? DateTime.now();
    var data = DateTime(ref.year, ref.month, ref.day, hora, minuto);
    if (!data.isAfter(ref)) data = data.add(const Duration(days: 1));
    return data;
  }

  Medicamento copyWith({
    String? nome,
    String? dosagem,
    int? hora,
    int? minuto,
    bool? ativo,
  }) {
    return Medicamento(
      id: id,
      nome: nome ?? this.nome,
      dosagem: dosagem ?? this.dosagem,
      hora: hora ?? this.hora,
      minuto: minuto ?? this.minuto,
      ativo: ativo ?? this.ativo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'dosagem': dosagem,
        'hora': hora,
        'minuto': minuto,
        'ativo': ativo,
      };

  factory Medicamento.fromJson(Map<String, dynamic> json) => Medicamento(
        id: json['id'] as int,
        nome: json['nome'] as String,
        dosagem: json['dosagem'] as String? ?? '',
        hora: json['hora'] as int,
        minuto: json['minuto'] as int,
        ativo: json['ativo'] as bool? ?? true,
      );
}
