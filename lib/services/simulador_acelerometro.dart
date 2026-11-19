import 'dart:math' as math;

/// Situações que o simulador consegue imitar.
enum ModoSimulacao {
  /// Celular apoiado na mesa: só a gravidade no eixo Z, quase sem variação.
  mesa,

  /// Celular na mão de alguém andando: os três eixos oscilam.
  andando,
}

extension ModoSimulacaoTexto on ModoSimulacao {
  String get rotulo => switch (this) {
    ModoSimulacao.mesa => 'Na mesa',
    ModoSimulacao.andando => 'Andando',
  };
}

/// Gera leituras X, Y, Z (m/s²) parecidas com as de um acelerômetro real.
///
/// Usado quando o dispositivo não tem o sensor — por exemplo, o Chrome
/// rodando no computador. As leituras passam pelo MESMO detector de
/// movimento das leituras reais, então parado/esquecido/brusco funcionam
/// igual ao celular.
class SimuladorAcelerometro {
  SimuladorAcelerometro({math.Random? aleatorio})
    : _aleatorio = aleatorio ?? math.Random();

  static const double gravidade = 9.81;

  /// Duração de um "chacoalhão".
  static const Duration duracaoChacoalhar = Duration(milliseconds: 1200);

  final math.Random _aleatorio;
  ModoSimulacao modo = ModoSimulacao.mesa;
  DateTime? _chacoalharAte;

  /// Simula o usuário chacoalhando o celular por ~1 segundo.
  void chacoalhar(DateTime agora) =>
      _chacoalharAte = agora.add(duracaoChacoalhar);

  bool chacoalhando(DateTime agora) =>
      _chacoalharAte != null && agora.isBefore(_chacoalharAte!);

  /// Leitura simulada no instante [agora].
  ({double x, double y, double z}) ler(DateTime agora) {
    final t = agora.millisecondsSinceEpoch / 1000;
    double ruido(double amplitude) =>
        (_aleatorio.nextDouble() * 2 - 1) * amplitude;

    if (chacoalhando(agora)) {
      // Trancos fortes para um lado e para o outro (~25 m/s² no eixo X).
      final lado = (t * 8).floor().isEven ? 1 : -1;
      return (x: lado * 25 + ruido(1), y: 2 + ruido(1), z: 6 + ruido(1));
    }

    switch (modo) {
      case ModoSimulacao.mesa:
        return (x: ruido(0.03), y: ruido(0.03), z: gravidade + ruido(0.03));
      case ModoSimulacao.andando:
        // Passos a ~1,8 Hz com o celular inclinado na mão.
        final w = 2 * math.pi * 1.8 * t;
        return (
          x: 0.8 * math.sin(w) + ruido(0.2),
          y: 4 + 2 * math.sin(2 * w) + ruido(0.3),
          z: 8.5 + 1.5 * math.cos(w) + ruido(0.3),
        );
    }
  }
}
