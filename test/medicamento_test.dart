import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/models/medicamento.dart';
import 'package:medlembrete/services/medicamento_repository.dart';
import 'package:medlembrete/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const losartana = Medicamento(
    id: 1,
    nome: 'Losartana',
    dosagem: '50 mg',
    hora: 8,
    minuto: 5,
  );

  group('Medicamento', () {
    test('formata o horário com dois dígitos', () {
      expect(losartana.horario, '08:05');
    });

    test('próxima ocorrência é hoje se o horário ainda não passou', () {
      final agora = DateTime(2026, 11, 18, 7, 0);
      expect(losartana.proximaOcorrencia(agora), DateTime(2026, 11, 18, 8, 5));
    });

    test('próxima ocorrência é amanhã se o horário já passou', () {
      final agora = DateTime(2026, 11, 18, 9, 0);
      expect(losartana.proximaOcorrencia(agora), DateTime(2026, 11, 19, 8, 5));
    });

    test('converte para JSON e de volta sem perder dados', () {
      final copia = Medicamento.fromJson(losartana.toJson());
      expect(copia.toJson(), losartana.toJson());
    });
  });

  group('NotificationService.idDoPayload', () {
    test('lê o id de um payload de dose', () {
      expect(NotificationService.idDoPayload('dose:42'), 42);
    });

    test('ignora payloads desconhecidos', () {
      expect(NotificationService.idDoPayload(null), isNull);
      expect(NotificationService.idDoPayload('outro:1'), isNull);
    });
  });

  group('MedicamentoRepository', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('salva, ordena por horário e persiste', () async {
      final repo = MedicamentoRepository.instance;
      await repo.carregar();
      await repo.salvar(losartana.copyWith(hora: 20));
      await repo.salvar(const Medicamento(
          id: 2, nome: 'Vitamina D', dosagem: '', hora: 7, minuto: 0));

      expect(repo.medicamentos.map((m) => m.nome), ['Vitamina D', 'Losartana']);

      await repo.carregar(); // relê do armazenamento
      expect(repo.medicamentos, hasLength(2));

      await repo.remover(2);
      expect(repo.porId(2), isNull);
    });

    test('próxima dose ignora remédios desativados', () async {
      final repo = MedicamentoRepository.instance;
      await repo.carregar();
      await repo.salvar(losartana.copyWith(ativo: false));
      await repo.salvar(const Medicamento(
          id: 3, nome: 'Omeprazol', dosagem: '', hora: 10, minuto: 0));

      final proxima = repo.proximaDose(DateTime(2026, 11, 18, 7));
      expect(proxima?.medicamento.nome, 'Omeprazol');
      expect(proxima?.horario, DateTime(2026, 11, 18, 10));
    });
  });
}
