import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/models/dose.dart';
import 'package:medlembrete/models/medicamento.dart';
import 'package:medlembrete/services/detector_movimento.dart';
import 'package:medlembrete/services/dose_repository.dart';
import 'package:medlembrete/services/medicamento_repository.dart';
import 'package:medlembrete/services/resumo_doses.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Dose guarda foto + GPS + estado do celular no JSON', () {
    final dose = Dose(
      id: 1,
      medicamentoId: 10,
      nomeMedicamento: 'Losartana',
      dosagem: '50 mg',
      horarioPrevisto: '08:00',
      dataHora: DateTime(2026, 11, 18, 8, 3),
      fotoPath: '/x.jpg',
      latitude: -16.328,
      longitude: -48.953,
      emCasa: true,
      distanciaCasaMetros: 12,
      estadoCelular: EstadoMovimento.parado,
    );
    final copia = Dose.fromJson(dose.toJson());
    expect(copia.toJson(), dose.toJson());
    expect(copia.estadoCelular, EstadoMovimento.parado);
    expect(copia.descricaoLocal, 'Em casa');
  });

  test('Dose antiga (sem GPS/sensor) continua sendo lida', () {
    final antiga = Dose.fromJson({
      'id': 1,
      'medicamentoId': 10,
      'nomeMedicamento': 'Losartana',
      'dataHora': '2026-11-18T08:03:00.000',
      'fotoPath': '/x.jpg',
    });
    expect(antiga.temLocalizacao, isFalse);
    expect(antiga.descricaoLocal, 'Sem localização');
  });

  test('ResumoDoses calcula pendentes e progresso do dia', () async {
    SharedPreferences.setMockInitialValues({});
    final meds = MedicamentoRepository.instance;
    final doses = DoseRepository.instance;
    await meds.carregar();
    await doses.carregar();

    await meds.salvar(const Medicamento(
        id: 1, nome: 'Manhã', dosagem: '', hora: 8, minuto: 0));
    await meds.salvar(const Medicamento(
        id: 2, nome: 'Almoço', dosagem: '', hora: 12, minuto: 0));
    await meds.salvar(const Medicamento(
        id: 3, nome: 'Noite', dosagem: '', hora: 21, minuto: 0));

    final agora = DateTime(2026, 11, 18, 13, 0);
    await doses.registrar(Dose(
      id: 1,
      medicamentoId: 1,
      nomeMedicamento: 'Manhã',
      dosagem: '',
      horarioPrevisto: '08:00',
      dataHora: DateTime(2026, 11, 18, 8, 5),
      fotoPath: '/x.jpg',
    ));

    expect(ResumoDoses.pendentesHoje(agora).map((m) => m.nome), ['Almoço']);
    expect(ResumoDoses.progressoHoje(agora), (1, 3));
  });
}
