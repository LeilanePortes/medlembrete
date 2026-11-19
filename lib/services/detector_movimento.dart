import 'dart:collection';
import 'dart:math' as math;

/// Estados possíveis do celular a partir do acelerômetro.
enum EstadoMovimento {
  /// Celular sendo carregado ou manuseado.
  emMovimento,

  /// Celular apoiado em algum lugar (mesa, cama...).
  parado,

  /// Parado há mais tempo que o limite: provavelmente esquecido.
  esquecido,
}

extension EstadoMovimentoTexto on EstadoMovimento {
  String get rotulo => switch (this) {
        EstadoMovimento.emMovimento => 'Em movimento',
        EstadoMovimento.parado => 'Parado',
        EstadoMovimento.esquecido => 'Provavelmente esquecido',
      };
}

/// Lógica pura (sem Flutter) que interpreta as leituras X, Y, Z.
///
/// Como funciona:
/// 1. Calcula a magnitude do vetor: √(x² + y² + z²).
///    Com o celular parado ela fica ≈ 9,8 m/s² (só a gravidade).
/// 2. Guarda as últimas N magnitudes (janela de ~1 s) e calcula o
///    desvio padrão. Desvio baixo = parado; desvio alto = em movimento.
/// 3. Se ficar parado por mais que [tempoEsquecido], vira "esquecido".
/// 4. Se a magnitude se afastar muito da gravidade, é um movimento brusco
///    (ex.: chacoalhar ou derrubar o celular).
class DetectorMovimento {
  DetectorMovimento({
    this.tamanhoJanela = 15,
    this.limiarParado = 0.3,
    this.limiarBrusco = 12,
    this.tempoEsquecido = const Duration(seconds: 30),
    this.intervaloEntreBruscos = const Duration(seconds: 1),
  });

  static const double gravidade = 9.81;

  final int tamanhoJanela;

  /// Desvio padrão (m/s²) abaixo do qual o celular é considerado parado.
  final double limiarParado;

  /// Diferença (m/s²) em relação à gravidade que caracteriza um tranco.
  final double limiarBrusco;

  Duration tempoEsquecido;
  final Duration intervaloEntreBruscos;

  final Queue<double> _janela = Queue<double>();
  DateTime? _paradoDesde;
  DateTime? _ultimoBrusco;

  EstadoMovimento estado = EstadoMovimento.emMovimento;
  double magnitude = gravidade;
  double desvio = 0;

  /// Há quanto tempo o celular está parado (zero se em movimento).
  Duration tempoParado(DateTime agora) =>
      _paradoDesde == null ? Duration.zero : agora.difference(_paradoDesde!);

  /// Processa uma leitura. Retorna true se ela foi um movimento brusco.
  bool adicionar(double x, double y, double z, DateTime agora) {
    magnitude = math.sqrt(x * x + y * y + z * z);

    _janela.addLast(magnitude);
    if (_janela.length > tamanhoJanela) _janela.removeFirst();
    desvio = _desvioPadrao(_janela);

    // Só decide depois de encher a janela, para evitar falsos positivos.
    if (_janela.length >= tamanhoJanela) {
      if (desvio < limiarParado) {
        _paradoDesde ??= agora;
        estado = tempoParado(agora) >= tempoEsquecido
            ? EstadoMovimento.esquecido
            : EstadoMovimento.parado;
      } else {
        _paradoDesde = null;
        estado = EstadoMovimento.emMovimento;
      }
    }

    final tranco = (magnitude - gravidade).abs() > limiarBrusco;
    final podeContar = _ultimoBrusco == null ||
        agora.difference(_ultimoBrusco!) >= intervaloEntreBruscos;
    if (tranco && podeContar) {
      _ultimoBrusco = agora;
      return true;
    }
    return false;
  }

  void reiniciar() {
    _janela.clear();
    _paradoDesde = null;
    _ultimoBrusco = null;
    estado = EstadoMovimento.emMovimento;
  }

  static double _desvioPadrao(Iterable<double> valores) {
    if (valores.length < 2) return 0;
    final media = valores.reduce((a, b) => a + b) / valores.length;
    final soma =
        valores.fold<double>(0, (acc, v) => acc + (v - media) * (v - media));
    return math.sqrt(soma / valores.length);
  }
}
