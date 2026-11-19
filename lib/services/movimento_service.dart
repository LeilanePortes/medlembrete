import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'detector_movimento.dart';

/// Uma leitura do acelerômetro (m/s²).
class LeituraAcelerometro {
  const LeituraAcelerometro(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// Escuta o acelerômetro em tempo real e expõe os valores X, Y, Z
/// e o estado do celular (parado / em movimento / esquecido).
class MovimentoService extends ChangeNotifier {
  MovimentoService._();
  static final MovimentoService instance = MovimentoService._();

  /// Quantas leituras guardar para o gráfico (~6 s a 15 Hz).
  static const int tamanhoHistorico = 90;

  final DetectorMovimento detector = DetectorMovimento();
  final Queue<LeituraAcelerometro> _historico = Queue();

  StreamSubscription<AccelerometerEvent>? _assinatura;
  LeituraAcelerometro? _ultima;
  int _movimentosBruscos = 0;
  String? erro;

  /// Avisado a cada movimento brusco detectado.
  final StreamController<void> _bruscos = StreamController<void>.broadcast();
  Stream<void> get bruscos => _bruscos.stream;

  LeituraAcelerometro? get ultima => _ultima;
  List<LeituraAcelerometro> get historico => List.unmodifiable(_historico);
  int get movimentosBruscos => _movimentosBruscos;
  EstadoMovimento get estado => detector.estado;
  bool get ativo => _assinatura != null;
  Duration get tempoParado => detector.tempoParado(DateTime.now());

  void iniciar() {
    if (_assinatura != null) return;
    erro = null;
    _assinatura = accelerometerEventStream(
      // ~15 leituras por segundo: suave para a tela e leve para a bateria.
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      _aoReceber,
      onError: (Object e) {
        erro = 'Acelerômetro indisponível neste aparelho.';
        parar();
      },
      cancelOnError: true,
    );
    notifyListeners();
  }

  void parar() {
    _assinatura?.cancel();
    _assinatura = null;
    detector.reiniciar();
    notifyListeners();
  }

  void zerarContador() {
    _movimentosBruscos = 0;
    notifyListeners();
  }

  void _aoReceber(AccelerometerEvent e) {
    final leitura = LeituraAcelerometro(e.x, e.y, e.z);
    _ultima = leitura;
    _historico.addLast(leitura);
    if (_historico.length > tamanhoHistorico) _historico.removeFirst();

    final brusco = detector.adicionar(e.x, e.y, e.z, DateTime.now());
    if (brusco) {
      _movimentosBruscos++;
      _bruscos.add(null);
    }
    notifyListeners();
  }
}
