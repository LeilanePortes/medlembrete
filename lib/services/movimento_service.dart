import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'detector_movimento.dart';
import 'simulador_acelerometro.dart';

/// Uma leitura do acelerômetro (m/s²).
class LeituraAcelerometro {
  const LeituraAcelerometro(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

/// Escuta o acelerômetro em tempo real e expõe os valores X, Y, Z
/// e o estado do celular (parado / em movimento / esquecido).
///
/// Se o dispositivo não tiver acelerômetro (ex.: Chrome no computador),
/// liga automaticamente o MODO SIMULAÇÃO, que gera valores artificiais
/// e os entrega ao mesmo detector de movimento.
class MovimentoService extends ChangeNotifier {
  MovimentoService._();
  static final MovimentoService instance = MovimentoService._();

  /// Quantas leituras guardar para o gráfico (~6 s a 15 Hz).
  static const int tamanhoHistorico = 90;

  /// Sem nenhuma leitura nesse tempo, consideramos que não há sensor.
  static const Duration tempoSemSensor = Duration(seconds: 3);

  /// ~15 leituras por segundo (mesmo ritmo do sensor real).
  static const Duration intervaloSimulacao = Duration(milliseconds: 66);

  final DetectorMovimento detector = DetectorMovimento();
  final SimuladorAcelerometro simulador = SimuladorAcelerometro();
  final Queue<LeituraAcelerometro> _historico = Queue();

  StreamSubscription<AccelerometerEvent>? _assinatura;
  Timer? _timerSimulacao;
  Timer? _timerVerificaSensor;

  bool _pausado = true;
  bool _simulando = false;
  bool _recebeuLeituraReal = false;
  bool _semSensor = false;

  LeituraAcelerometro? _ultima;
  int _movimentosBruscos = 0;

  /// Avisado a cada movimento brusco detectado.
  final StreamController<void> _bruscos = StreamController<void>.broadcast();
  Stream<void> get bruscos => _bruscos.stream;

  LeituraAcelerometro? get ultima => _ultima;
  List<LeituraAcelerometro> get historico => List.unmodifiable(_historico);
  int get movimentosBruscos => _movimentosBruscos;
  EstadoMovimento get estado => detector.estado;
  bool get ativo => !_pausado;
  Duration get tempoParado => detector.tempoParado(DateTime.now());

  /// true se as leituras atuais vêm do simulador.
  bool get simulando => _simulando;

  /// true se o dispositivo não entregou nenhuma leitura real.
  bool get semSensor => _semSensor;

  void iniciar() {
    if (!_pausado) return;
    _pausado = false;
    if (_simulando) {
      _ligarSimulacao();
    } else {
      _escutarSensor();
    }
    notifyListeners();
  }

  void parar() {
    _pausado = true;
    _timerSimulacao?.cancel();
    _timerSimulacao = null;
    _timerVerificaSensor?.cancel();
    // No celular, desliga o sensor para economizar bateria. Na web a
    // assinatura é mantida: o plugin não consegue reabrir o sensor.
    if (!kIsWeb) {
      _assinatura?.cancel();
      _assinatura = null;
    }
    detector.reiniciar();
    notifyListeners();
  }

  /// Liga ou desliga o modo simulação.
  void definirSimulacao(bool valor) {
    _simulando = valor;
    _historico.clear();
    _ultima = null;
    detector.reiniciar();
    _timerSimulacao?.cancel();
    _timerSimulacao = null;
    if (!_pausado) {
      if (valor) {
        _ligarSimulacao();
      } else {
        _escutarSensor();
      }
    }
    notifyListeners();
  }

  void definirModoSimulacao(ModoSimulacao modo) {
    simulador.modo = modo;
    notifyListeners();
  }

  void chacoalhar() => simulador.chacoalhar(DateTime.now());

  void zerarContador() {
    _movimentosBruscos = 0;
    notifyListeners();
  }

  void _escutarSensor() {
    _assinatura ??= accelerometerEventStream(
      // ~15 leituras por segundo: suave para a tela e leve para a bateria.
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_aoReceberDoSensor, onError: (Object _) => _detectouSemSensor());

    // Se nada chegar em poucos segundos, não há acelerômetro.
    if (!_recebeuLeituraReal) {
      _timerVerificaSensor?.cancel();
      _timerVerificaSensor = Timer(tempoSemSensor, () {
        if (!_recebeuLeituraReal) _detectouSemSensor();
      });
    }
  }

  void _detectouSemSensor() {
    if (_semSensor) return;
    _semSensor = true;
    debugPrint('Acelerômetro indisponível: ligando o modo simulação.');
    definirSimulacao(true);
  }

  void _ligarSimulacao() {
    _timerSimulacao ??= Timer.periodic(intervaloSimulacao, (_) {
      final l = simulador.ler(DateTime.now());
      _processar(l.x, l.y, l.z);
    });
  }

  void _aoReceberDoSensor(AccelerometerEvent e) {
    // Na web sem sensor, o plugin envia uma única leitura (0, 0, 0).
    if (e.x == 0 && e.y == 0 && e.z == 0 && !_recebeuLeituraReal) {
      _detectouSemSensor();
      return;
    }
    _recebeuLeituraReal = true;
    if (_pausado || _simulando) return;
    _processar(e.x, e.y, e.z);
  }

  void _processar(double x, double y, double z) {
    final leitura = LeituraAcelerometro(x, y, z);
    _ultima = leitura;
    _historico.addLast(leitura);
    if (_historico.length > tamanhoHistorico) _historico.removeFirst();

    final brusco = detector.adicionar(x, y, z, DateTime.now());
    if (brusco) {
      _movimentosBruscos++;
      _bruscos.add(null);
    }
    notifyListeners();
  }
}
