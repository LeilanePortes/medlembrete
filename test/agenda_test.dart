import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/models/dose.dart';
import 'package:medlembrete/models/medicamento.dart';
import 'package:medlembrete/services/dose_repository.dart';
import 'package:medlembrete/services/medicamento_repository.dart';
import 'package:medlembrete/services/resumo_doses.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 18/11/2026 é uma quarta-feira.
final quarta18 = DateTime(2026, 11, 18);

/// Antibiótico: começa dia 18 às 08:00, de 8 em 8 h, por 7 dias.
final amoxicilina = Medicamento(
  id: 1,
  nome: 'Amoxicilina',
  dosagem: '500 mg',
  hora: 8,
  minuto: 0,
  dataInicio: quarta18,
  intervaloHoras: 8,
  duracaoDias: 7,
);

/// Vitamina às segundas, quartas e sextas, 1x ao dia, uso contínuo.
final vitamina = Medicamento(
  id: 2,
  nome: 'Vitamina D',
  dosagem: '',
  hora: 9,
  minuto: 30,
  dataInicio: quarta18,
  diasSemana: const {DateTime.monday, DateTime.wednesday, DateTime.friday},
);

Dose comprovante(Medicamento m, DateTime previsto, {int id = 1}) => Dose(
      id: id,
      medicamentoId: m.id,
      nomeMedicamento: m.nome,
      dosagem: m.dosagem,
      horarioPrevisto: '',
      dataHora: previsto.add(const Duration(minutes: 3)),
      fotoPath: '/x.jpg',
      previstoPara: previsto,
    );

void main() {
  group('Frequência', () {
    test('de 8 em 8 h a partir das 08:00 → 00:00, 08:00, 16:00', () {
      expect(amoxicilina.minutosDoDia, [0, 480, 960]);
      expect(amoxicilina.horariosDoDia, ['00:00', '08:00', '16:00']);
      expect(amoxicilina.descricaoFrequencia, 'De 8 em 8 h');
    });

    test('1x ao dia tem um único horário', () {
      expect(vitamina.horariosDoDia, ['09:30']);
      expect(vitamina.descricaoFrequencia, '1x ao dia');
    });

    test('de 6 em 6 h a partir das 07:15 → 4 horários', () {
      const m = Medicamento(
          id: 9, nome: 'x', dosagem: '', hora: 7, minuto: 15,
          intervaloHoras: 6);
      expect(m.horariosDoDia, ['01:15', '07:15', '13:15', '19:15']);
    });
  });

  group('Duração (tratamento por N dias)', () {
    test('7 dias de 8 em 8 h = 21 doses, da 1ª às 08:00 até 25/11 00:00', () {
      final doses =
          amoxicilina.ocorrenciasEntre(amoxicilina.inicio!, amoxicilina.fim!);
      expect(doses, hasLength(21));
      expect(doses.first, DateTime(2026, 11, 18, 8));
      expect(doses.last, DateTime(2026, 11, 25, 0));
      expect(amoxicilina.ultimaOcorrencia, DateTime(2026, 11, 25, 0));
    });

    test('no 1º dia não há dose antes do início (00:00 fica de fora)', () {
      expect(amoxicilina.ocorrenciasNoDia(quarta18), [
        DateTime(2026, 11, 18, 8),
        DateTime(2026, 11, 18, 16),
      ]);
    });

    test('antes de começar, a próxima dose é a 1ª do tratamento', () {
      expect(amoxicilina.proximaOcorrencia(DateTime(2026, 11, 10)),
          DateTime(2026, 11, 18, 8));
    });

    test('depois da última dose, o tratamento está encerrado', () {
      final depois = DateTime(2026, 11, 25, 1);
      expect(amoxicilina.proximaOcorrencia(depois), isNull);
      expect(amoxicilina.encerrado(depois), isTrue);
      expect(amoxicilina.encerrado(DateTime(2026, 11, 20)), isFalse);
    });

    test('uso contínuo não tem fim', () {
      expect(vitamina.continuo, isTrue);
      expect(vitamina.fim, isNull);
      expect(vitamina.ultimaOcorrencia, isNull);
    });
  });

  group('Dias da semana', () {
    test('seg/qua/sex: depois de quarta 09:30 a próxima é sexta', () {
      expect(vitamina.proximaOcorrencia(DateTime(2026, 11, 18, 10)),
          DateTime(2026, 11, 20, 9, 30));
    });

    test('depois de sexta, pula o fim de semana até segunda', () {
      expect(vitamina.proximaOcorrencia(DateTime(2026, 11, 20, 12)),
          DateTime(2026, 11, 23, 9, 30));
    });

    test('quinta não tem dose', () {
      expect(vitamina.ocorrenciasNoDia(DateTime(2026, 11, 19)), isEmpty);
    });

    test('descrição dos dias', () {
      expect(vitamina.descricaoDias, 'Seg, Qua, Sex');
      expect(Medicamento.descreverDias({1, 2, 3, 4, 5}), 'Seg a Sex');
      expect(Medicamento.descreverDias(Medicamento.todosOsDias),
          'Todos os dias');
    });
  });

  group('JSON', () {
    test('ida e volta com a agenda completa', () {
      final copia = Medicamento.fromJson(amoxicilina.toJson());
      expect(copia.toJson(), amoxicilina.toJson());
      expect(copia.dataInicio, quarta18);
      expect(copia.diasSemana, Medicamento.todosOsDias);
    });

    test('remédio salvo antes da agenda vira 1x ao dia, contínuo', () {
      final antigo = Medicamento.fromJson({
        'id': 5,
        'nome': 'Losartana',
        'dosagem': '50 mg',
        'hora': 8,
        'minuto': 0,
        'ativo': true,
      });
      expect(antigo.intervaloHoras, 24);
      expect(antigo.todaSemana, isTrue);
      expect(antigo.continuo, isTrue);
      expect(antigo.proximaOcorrencia(DateTime(2026, 11, 18, 7)),
          DateTime(2026, 11, 18, 8));
    });
  });

  group('ResumoDoses com várias doses por dia', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await MedicamentoRepository.instance.carregar();
      await DoseRepository.instance.carregar();
      await MedicamentoRepository.instance.salvar(amoxicilina);
      await MedicamentoRepository.instance.salvar(vitamina);
    });

    test('agenda, progresso e atrasadas do dia', () async {
      // Quinta 19/11 às 17:00: amoxicilina 00:00, 08:00, 16:00; vitamina não.
      final agora = DateTime(2026, 11, 19, 17);
      await DoseRepository.instance
          .registrar(comprovante(amoxicilina, DateTime(2026, 11, 19, 8)));

      expect(ResumoDoses.agendaDoDia(agora), hasLength(3));
      expect(ResumoDoses.progressoHoje(agora), (1, 3));
      expect(
        ResumoDoses.atrasadasHoje(agora).map((d) => d.horario),
        [DateTime(2026, 11, 19, 0), DateTime(2026, 11, 19, 16)],
      );
      expect(ResumoDoses.pendentesHoje(agora).map((m) => m.nome),
          ['Amoxicilina']);
    });

    test('comprova a dose ainda não tomada mais próxima do horário', () async {
      // 15:50: a das 16:00 está mais perto que a das 08:00.
      expect(
          ResumoDoses.doseParaComprovar(
              amoxicilina, DateTime(2026, 11, 19, 15, 50)),
          DateTime(2026, 11, 19, 16));

      // 11:00 com a das 08:00 esquecida: comprova a das 08:00.
      expect(
          ResumoDoses.doseParaComprovar(
              amoxicilina, DateTime(2026, 11, 19, 11)),
          DateTime(2026, 11, 19, 8));

      // Se a das 08:00 já foi tomada, às 11:00 a próxima é a das 16:00
      // (fora da janela de 2 h → próxima da agenda).
      await DoseRepository.instance
          .registrar(comprovante(amoxicilina, DateTime(2026, 11, 19, 8)));
      await DoseRepository.instance.registrar(
          comprovante(amoxicilina, DateTime(2026, 11, 19, 0), id: 2));
      await DoseRepository.instance.registrar(
          comprovante(amoxicilina, DateTime(2026, 11, 18, 16), id: 3));
      expect(
          ResumoDoses.doseParaComprovar(
              amoxicilina, DateTime(2026, 11, 19, 11)),
          DateTime(2026, 11, 19, 16));
    });

    test('próxima dose geral considera todos os remédios', () {
      final proxima = MedicamentoRepository.instance
          .proximaDose(DateTime(2026, 11, 20, 9));
      expect(proxima?.medicamento.nome, 'Vitamina D');
      expect(proxima?.horario, DateTime(2026, 11, 20, 9, 30));
    });
  });
}
