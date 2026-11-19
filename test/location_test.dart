import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('formata distâncias em metros e quilômetros', () {
    expect(LocationService.formatarDistancia(35.4), '35 m');
    expect(LocationService.formatarDistancia(2430), '2,4 km');
  });

  test('raio de 100 m define "em casa"', () {
    expect(LocationService.dentroDoRaio(80), isTrue);
    expect(LocationService.dentroDoRaio(100), isTrue);
    expect(LocationService.dentroDoRaio(150), isFalse);
  });

  test('salva a casa e calcula se está em casa ou fora', () async {
    SharedPreferences.setMockInitialValues({});
    final servico = LocationService.instance;
    await servico.carregarCasa();
    expect(servico.estaEmCasa(-16.3, -48.9), isNull);

    await servico.definirCasa(const Coordenada(-16.328, -48.953));
    await servico.carregarCasa(); // relê do armazenamento

    // ~11 m de distância -> em casa
    expect(servico.estaEmCasa(-16.3281, -48.953), isTrue);
    // ~1,1 km de distância -> fora
    expect(servico.estaEmCasa(-16.338, -48.953), isFalse);

    await servico.limparCasa();
    expect(servico.casa, isNull);
  });
}
