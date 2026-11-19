import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/services/detector_movimento.dart';

void main() {
  final inicio = DateTime(2026, 11, 18, 8);
  DateTime t(int ms) => inicio.add(Duration(milliseconds: ms));

  test('celular apoiado na mesa é detectado como parado', () {
    final d = DetectorMovimento();
    for (var i = 0; i < 20; i++) {
      d.adicionar(0.02, 0.05, 9.81, t(i * 66));
    }
    expect(d.estado, EstadoMovimento.parado);
  });

  test('leituras oscilando indicam movimento', () {
    final d = DetectorMovimento();
    for (var i = 0; i < 20; i++) {
      final oscila = i.isEven ? 3.0 : -3.0;
      d.adicionar(oscila, 2, 9.81 + oscila, t(i * 66));
    }
    expect(d.estado, EstadoMovimento.emMovimento);
  });

  test('parado por mais tempo que o limite vira "esquecido"', () {
    final d = DetectorMovimento(tempoEsquecido: const Duration(seconds: 5));
    var ms = 0;
    while (ms <= 6000) {
      d.adicionar(0, 0, 9.81, t(ms));
      ms += 66;
    }
    expect(d.estado, EstadoMovimento.esquecido);

    // Pegou o celular de novo: volta a "em movimento".
    for (var i = 0; i < 10; i++) {
      d.adicionar(i.isEven ? 6 : 0, 0, 9.81, t(ms + i * 66));
    }
    expect(d.estado, EstadoMovimento.emMovimento);
  });

  test('tranco forte conta como movimento brusco (com intervalo mínimo)', () {
    final d = DetectorMovimento();
    expect(d.adicionar(0, 0, 9.81, t(0)), isFalse);
    expect(d.adicionar(20, 15, 9.81, t(100)), isTrue);
    // Outro tranco logo em seguida não conta de novo.
    expect(d.adicionar(20, 15, 9.81, t(300)), isFalse);
    // Depois de 1 s conta novamente.
    expect(d.adicionar(20, 15, 9.81, t(1200)), isTrue);
  });
}
