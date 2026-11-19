import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/services/camera_service.dart';
import 'package:medlembrete/services/detector_movimento.dart';
import 'package:medlembrete/services/notification_service.dart';
import 'package:medlembrete/services/simulador_acelerometro.dart';

/// Alimenta o detector com [segundos] de leituras simuladas a 15 Hz.
/// Retorna quantos movimentos bruscos foram detectados.
int simular(
  SimuladorAcelerometro simulador,
  DetectorMovimento detector,
  DateTime inicio, {
  double segundos = 2,
  void Function(DateTime agora)? aCadaLeitura,
}) {
  var bruscos = 0;
  final total = (segundos * 15).round();
  for (var i = 0; i < total; i++) {
    final agora = inicio.add(Duration(milliseconds: i * 66));
    aCadaLeitura?.call(agora);
    final l = simulador.ler(agora);
    if (detector.adicionar(l.x, l.y, l.z, agora)) bruscos++;
  }
  return bruscos;
}

void main() {
  final inicio = DateTime(2026, 11, 18, 10);

  group('SimuladorAcelerometro + DetectorMovimento', () {
    test('"Na mesa" é detectado como parado', () {
      final simulador = SimuladorAcelerometro(aleatorio: math.Random(1));
      final detector = DetectorMovimento();
      final bruscos = simular(simulador, detector, inicio);
      expect(detector.estado, EstadoMovimento.parado);
      expect(bruscos, 0);
      expect(detector.magnitude, closeTo(9.81, 0.2));
    });

    test('"Na mesa" por mais que o limite vira esquecido', () {
      final simulador = SimuladorAcelerometro(aleatorio: math.Random(2));
      final detector =
          DetectorMovimento(tempoEsquecido: const Duration(seconds: 3));
      simular(simulador, detector, inicio, segundos: 5);
      expect(detector.estado, EstadoMovimento.esquecido);
    });

    test('"Andando" é detectado como em movimento', () {
      final simulador = SimuladorAcelerometro(aleatorio: math.Random(3))
        ..modo = ModoSimulacao.andando;
      final detector = DetectorMovimento();
      simular(simulador, detector, inicio);
      expect(detector.estado, EstadoMovimento.emMovimento);
    });

    test('"Chacoalhar" gera movimento brusco e depois volta ao normal', () {
      final simulador = SimuladorAcelerometro(aleatorio: math.Random(4));
      final detector = DetectorMovimento();
      simulador.chacoalhar(inicio);
      final bruscos = simular(simulador, detector, inicio, segundos: 1);
      expect(bruscos, greaterThanOrEqualTo(1));
      expect(
        simulador.chacoalhando(
            inicio.add(SimuladorAcelerometro.duracaoChacoalhar)),
        isFalse,
      );
    });
  });

  group('Fotos no navegador (data URL)', () {
    test('ida e volta preserva os bytes', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      final url = CameraService.paraDataUrl(bytes);
      expect(url, startsWith('data:image/jpeg;base64,'));
      expect(CameraService.ehDataUrl(url), isTrue);
      expect(CameraService.bytesDoDataUrl(url), bytes);
    });

    test('caminho de arquivo não é data URL', () {
      expect(CameraService.ehDataUrl('/data/user/0/app/dose_1.jpg'), isFalse);
    });
  });

  group('NotificationService.idNotificacao', () {
    test('cada dose de um remédio tem um ID diferente', () {
      final ids = {
        for (var n = 0; n < 200; n++)
          NotificationService.idNotificacao(1763469000, n),
      };
      expect(ids, hasLength(200));
      expect(ids.every((id) => id >= 0 && id <= 0x7fffffff), isTrue);
    });
  });
}
