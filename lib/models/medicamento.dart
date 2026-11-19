/// Um remédio cadastrado pelo usuário e a sua agenda de doses.
///
/// A agenda é definida por:
/// - [dataInicio]: dia em que o tratamento começa (null = remédio antigo,
///   cadastrado antes da agenda existir: vale "desde sempre");
/// - [hora]:[minuto]: horário da 1ª dose do dia;
/// - [intervaloHoras]: de quantas em quantas horas (4, 6, 8, 12 ou 24);
/// - [diasSemana]: em quais dias da semana tomar;
/// - [duracaoDias]: por quantos dias (null = uso contínuo).
///
/// Como todos os intervalos dividem 24 h, os horários se repetem iguais
/// todos os dias. Ex.: 08:00 de 8 em 8 h → 00:00, 08:00 e 16:00.
///
/// Estoque (opcional): [estoque] unidades em casa, [unidadesPorDose]
/// descontadas a cada dose comprovada e aviso quando sobrarem doses para
/// [avisarDias] dias.
class Medicamento {
  const Medicamento({
    required this.id,
    required this.nome,
    required this.dosagem,
    required this.hora,
    required this.minuto,
    this.ativo = true,
    this.dataInicio,
    this.intervaloHoras = 24,
    this.diasSemana = todosOsDias,
    this.duracaoDias,
    this.estoque,
    this.unidadesPorDose = 1,
    this.unidade = 'comprimido',
    this.avisarDias = 3,
  });

  /// Frequências oferecidas no cadastro.
  static const List<int> intervalosPermitidos = [4, 6, 8, 12, 24];

  /// Dias da semana no padrão do Dart: segunda = 1 ... domingo = 7.
  static const Set<int> todosOsDias = {1, 2, 3, 4, 5, 6, 7};
  /// Unidades oferecidas no cadastro (singular → plural).
  static const Map<String, String> unidades = {
    'comprimido': 'comprimidos',
    'cápsula': 'cápsulas',
    'gota': 'gotas',
    'mL': 'mL',
  };

  /// Opções de "avisar quando restar N dias".
  static const List<int> opcoesAvisarDias = [1, 3, 5, 7];

  static const List<String> nomesDias = [
    'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom', //
  ];

  /// Identificador único (também identifica as notificações do remédio).
  final int id;
  final String nome;

  /// Ex.: "1 comprimido", "500 mg", "10 gotas".
  final String dosagem;

  /// Horário da 1ª dose do dia.
  final int hora;
  final int minuto;

  /// Quando falso, os lembretes ficam desligados.
  final bool ativo;

  /// Só a data (sem horário) em que o tratamento começa.
  final DateTime? dataInicio;
  final int intervaloHoras;
  final Set<int> diasSemana;

  /// Quantos dias o tratamento dura. null = uso contínuo.
  final int? duracaoDias;

  /// Unidades em casa. null = o usuário não controla o estoque.
  final int? estoque;
  final int unidadesPorDose;

  /// Chave de [unidades], ex.: "comprimido".
  final String unidade;

  /// Avisar quando o estoque der para só esse número de dias.
  final int avisarDias;

  /// Gera um ID inteiro de 31 bits (limite das notificações no Android).
  static int novoId() =>
      DateTime.now().millisecondsSinceEpoch.remainder(0x7fffffff);

  /// Horário da 1ª dose, ex.: "08:05".
  String get horario => _formatarMinutos(hora * 60 + minuto);

  // ---------------------------------------------------------------------
  // Agenda
  // ---------------------------------------------------------------------

  bool get continuo => duracaoDias == null || dataInicio == null;
  bool get todaSemana => diasSemana.length == 7;

  /// Momento da 1ª dose do tratamento (null se não há data de início).
  DateTime? get inicio {
    final d = dataInicio;
    return d == null ? null : DateTime(d.year, d.month, d.day, hora, minuto);
  }

  /// Fim do tratamento (exclusivo). null = uso contínuo.
  DateTime? get fim {
    final i = inicio;
    if (continuo || i == null) return null;
    return DateTime(i.year, i.month, i.day + duracaoDias!, i.hour, i.minute);
  }

  /// Minutos do dia de cada dose, em ordem. Ex.: 08:00 de 8 em 8 h →
  /// [0, 480, 960] (00:00, 08:00 e 16:00).
  List<int> get minutosDoDia {
    final base = hora * 60 + minuto;
    final doses = 24 ~/ intervaloHoras;
    return [
      for (var k = 0; k < doses; k++) (base + k * intervaloHoras * 60) % 1440,
    ]..sort();
  }

  /// Ex.: ["00:00", "08:00", "16:00"].
  List<String> get horariosDoDia =>
      minutosDoDia.map(_formatarMinutos).toList();

  bool _valida(DateTime t) {
    if (!diasSemana.contains(t.weekday)) return false;
    final i = inicio;
    if (i != null && t.isBefore(i)) return false;
    final f = fim;
    if (f != null && !t.isBefore(f)) return false;
    return true;
  }

  /// Todas as doses entre [de] (inclusive) e [ate] (exclusive), em ordem.
  List<DateTime> ocorrenciasEntre(DateTime de, DateTime ate) {
    final resultado = <DateTime>[];
    final minutos = minutosDoDia;
    var dia = DateTime(de.year, de.month, de.day);
    while (dia.isBefore(ate)) {
      for (final m in minutos) {
        final t = DateTime(dia.year, dia.month, dia.day, m ~/ 60, m % 60);
        if (!t.isBefore(de) && t.isBefore(ate) && _valida(t)) {
          resultado.add(t);
        }
      }
      dia = DateTime(dia.year, dia.month, dia.day + 1);
    }
    return resultado;
  }

  /// Doses previstas para o dia de [dia].
  List<DateTime> ocorrenciasNoDia(DateTime dia) => ocorrenciasEntre(
        DateTime(dia.year, dia.month, dia.day),
        DateTime(dia.year, dia.month, dia.day + 1),
      );

  /// Próxima dose depois de [agora]. null se o tratamento já terminou.
  DateTime? proximaOcorrencia([DateTime? agora]) {
    var de = (agora ?? DateTime.now()).add(const Duration(microseconds: 1));
    final i = inicio;
    if (i != null && i.isAfter(de)) de = i;
    // 8 dias cobrem qualquer combinação de dias da semana.
    var ate = DateTime(de.year, de.month, de.day + 8);
    final f = fim;
    if (f != null && f.isBefore(ate)) ate = f;
    final lista = ocorrenciasEntre(de, ate);
    return lista.isEmpty ? null : lista.first;
  }

  /// Última dose do tratamento (null se for uso contínuo).
  DateTime? get ultimaOcorrencia {
    final f = fim;
    if (f == null) return null;
    final lista = ocorrenciasEntre(
        DateTime(f.year, f.month, f.day - 8), f);
    return lista.isEmpty ? null : lista.last;
  }

  /// true se o tratamento tem fim e todas as doses já passaram.
  bool encerrado([DateTime? agora]) =>
      fim != null && proximaOcorrencia(agora) == null;

  // ---------------------------------------------------------------------
  // Estoque
  // ---------------------------------------------------------------------

  bool get controlaEstoque => estoque != null;

  /// Doses por dia, em média (considera os dias da semana).
  double get dosesPorDia => (24 / intervaloHoras) * diasSemana.length / 7;

  /// Unidades gastas por dia, em média.
  double get consumoDiario => dosesPorDia * unidadesPorDose;

  /// Abaixo (ou igual) a esse número de unidades o estoque está baixo.
  int get limiteAviso {
    final limite = (consumoDiario * avisarDias).ceil();
    return limite < unidadesPorDose ? unidadesPorDose : limite;
  }

  bool get estoqueBaixo => controlaEstoque && estoque! <= limiteAviso;
  bool get estoqueAcabou => controlaEstoque && estoque! < unidadesPorDose;

  /// Primeira e última dose que o estoque atual consegue cobrir a partir
  /// de [agora] (null se não controla estoque ou não cobre nenhuma dose).
  (DateTime, DateTime)? _coberturaDoEstoque(DateTime agora) {
    if (!controlaEstoque) return null;
    final doses = estoque! ~/ unidadesPorDose;
    if (doses == 0) return null;
    var de = agora;
    final i = inicio;
    if (i != null && i.isAfter(de)) de = i;
    DateTime? primeira;
    DateTime? ultima;
    var contadas = 0;
    // Procura de 30 em 30 dias (no máximo ~2 anos).
    for (var bloco = 0; bloco < 25 && contadas < doses; bloco++) {
      final ate = DateTime(de.year, de.month, de.day + 30);
      for (final t in ocorrenciasEntre(de, ate)) {
        primeira ??= t;
        ultima = t;
        if (++contadas == doses) break;
      }
      de = ate;
      final f = fim;
      if (f != null && !de.isBefore(f)) break;
    }
    return primeira == null ? null : (primeira, ultima!);
  }

  /// Data da última dose que o estoque atual consegue cobrir.
  DateTime? estoqueDuraAte([DateTime? agora]) =>
      _coberturaDoEstoque(agora ?? DateTime.now())?.$2;

  /// Quantos dias de tratamento o estoque cobre, do dia da próxima dose
  /// ao dia da última dose coberta (inclusive).
  int? diasDeEstoque([DateTime? agora]) {
    if (!controlaEstoque) return null;
    final cobertura = _coberturaDoEstoque(agora ?? DateTime.now());
    if (cobertura == null) return 0;
    final (primeira, ultima) = cobertura;
    final dia1 = DateTime(primeira.year, primeira.month, primeira.day);
    final diaN = DateTime(ultima.year, ultima.month, ultima.day);
    return diaN.difference(dia1).inDays + 1;
  }

  /// Unidades necessárias para as doses que faltam no tratamento
  /// (null se for uso contínuo).
  int? unidadesAteOFim([DateTime? agora]) {
    final f = fim;
    if (f == null) return null;
    var de = agora ?? DateTime.now();
    final i = inicio!;
    if (i.isAfter(de)) de = i;
    return ocorrenciasEntre(de, f).length * unidadesPorDose;
  }

  /// Quantas unidades faltam para terminar o tratamento (0 se o estoque
  /// basta; null se não controla estoque ou é uso contínuo).
  int? faltaParaOFim([DateTime? agora]) {
    final precisa = unidadesAteOFim(agora);
    if (precisa == null || !controlaEstoque) return null;
    final falta = precisa - estoque!;
    return falta > 0 ? falta : 0;
  }

  /// "1 comprimido", "12 comprimidos", "5 mL".
  String descreverQuantidade(int n) =>
      '$n ${n == 1 ? unidade : unidades[unidade] ?? unidade}';

  /// Cópia com outro estoque (inclusive null = parar de controlar).
  Medicamento comEstoque(int? novoEstoque) => Medicamento(
        id: id,
        nome: nome,
        dosagem: dosagem,
        hora: hora,
        minuto: minuto,
        ativo: ativo,
        dataInicio: dataInicio,
        intervaloHoras: intervaloHoras,
        diasSemana: diasSemana,
        duracaoDias: duracaoDias,
        estoque: novoEstoque,
        unidadesPorDose: unidadesPorDose,
        unidade: unidade,
        avisarDias: avisarDias,
      );

  // ---------------------------------------------------------------------
  // Textos
  // ---------------------------------------------------------------------

  /// "1x ao dia" ou "De 8 em 8 h".
  String get descricaoFrequencia => descreverIntervalo(intervaloHoras);

  static String descreverIntervalo(int horas) =>
      horas == 24 ? '1x ao dia' : 'De $horas em $horas h';

  /// "Todos os dias" ou "Seg, Qua, Sex".
  String get descricaoDias => descreverDias(diasSemana);

  static String descreverDias(Set<int> dias) {
    if (dias.length == 7) return 'Todos os dias';
    if (dias.length == 5 && !dias.contains(6) && !dias.contains(7)) {
      return 'Seg a Sex';
    }
    final ordenados = dias.toList()..sort();
    return ordenados.map((d) => nomesDias[d - 1]).join(', ');
  }

  static String _formatarMinutos(int minutos) =>
      '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutos % 60).toString().padLeft(2, '0')}';

  // ---------------------------------------------------------------------

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
      dataInicio: dataInicio,
      intervaloHoras: intervaloHoras,
      diasSemana: diasSemana,
      duracaoDias: duracaoDias,
      estoque: estoque,
      unidadesPorDose: unidadesPorDose,
      unidade: unidade,
      avisarDias: avisarDias,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'dosagem': dosagem,
        'hora': hora,
        'minuto': minuto,
        'ativo': ativo,
        'dataInicio': dataInicio?.toIso8601String().substring(0, 10),
        'intervaloHoras': intervaloHoras,
        'diasSemana': diasSemana.toList()..sort(),
        'duracaoDias': duracaoDias,
        'estoque': estoque,
        'unidadesPorDose': unidadesPorDose,
        'unidade': unidade,
        'avisarDias': avisarDias,
      };

  /// Lê também remédios salvos antes da agenda existir (sem os campos
  /// novos): ficam como 1x ao dia, todos os dias, uso contínuo.
  factory Medicamento.fromJson(Map<String, dynamic> json) {
    final inicio = json['dataInicio'] as String?;
    final intervalo = json['intervaloHoras'] as int? ?? 24;
    final dias = (json['diasSemana'] as List<dynamic>?)?.cast<int>().toSet();
    return Medicamento(
      id: json['id'] as int,
      nome: json['nome'] as String,
      dosagem: json['dosagem'] as String? ?? '',
      hora: json['hora'] as int,
      minuto: json['minuto'] as int,
      ativo: json['ativo'] as bool? ?? true,
      dataInicio: inicio == null ? null : DateTime.parse(inicio),
      intervaloHoras:
          intervalosPermitidos.contains(intervalo) ? intervalo : 24,
      diasSemana: (dias == null || dias.isEmpty) ? todosOsDias : dias,
      duracaoDias: json['duracaoDias'] as int?,
      estoque: json['estoque'] as int?,
      unidadesPorDose: json['unidadesPorDose'] as int? ?? 1,
      unidade: unidades.containsKey(json['unidade'])
          ? json['unidade'] as String
          : 'comprimido',
      avisarDias: json['avisarDias'] as int? ?? 3,
    );
  }
}
