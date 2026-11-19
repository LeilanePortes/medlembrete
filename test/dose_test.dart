import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/core/formatters.dart';
import 'package:medlembrete/models/dose.dart';
import 'package:medlembrete/services/dose_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final dose = Dose(
    id: 1,
    medicamentoId: 10,
    nomeMedicamento: 'Losartana',
    dosagem: '50 mg',
    horarioPrevisto: '08:00',
    dataHora: DateTime(2026, 11, 18, 8, 3),
    fotoPath: '/tmp/nao_existe.jpg',
  );

  test('Dose converte para JSON e de volta', () {
    expect(Dose.fromJson(dose.toJson()).toJson(), dose.toJson());
  });

  test('formatadores pt-BR', () {
    expect(formatarDataHora(DateTime(2026, 1, 5, 7, 9)), '05/01/2026 às 07:09');
  });

  test('DoseRepository identifica dose tomada hoje', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = DoseRepository.instance;
    await repo.carregar();
    await repo.registrar(dose);

    expect(repo.tomadaHoje(10, DateTime(2026, 11, 18, 20)), isNotNull);
    expect(repo.tomadaHoje(10, DateTime(2026, 11, 19, 8)), isNull);
    expect(repo.tomadaHoje(99, DateTime(2026, 11, 18, 20)), isNull);
  });
}
