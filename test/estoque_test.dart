import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/models/dose.dart';
import 'package:medlembrete/models/medicamento.dart';
import 'package:medlembrete/services/dose_repository.dart';
import 'package:medlembrete/services/estoque_service.dart';
import 'package:medlembrete/services/medicamento_repository.dart';
import 'package:medlembrete/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 18/11/2026 é uma quarta-feira.
final quarta18 = DateTime(2026, 11, 18);

Medicamento losartana({int? estoque = 10, int porDose = 1}) => Medicamento(
      id: 1,
      nome: 'Losartana',
      dosagem: '50 mg',
      hora: 8,
      minuto: 0,
      dataInicio: quarta18,
      estoque: estoque,
      unidadesPorDose: porDose,
    );

/// De 8 em 8 h por 7 dias = 21 doses.
Medicamento amoxicilina({int? estoque}) => Medicamento(
      id: 2,
      nome: 'Amoxicilina',
      dosagem: '500 mg',
      hora: 8,
      minuto: 0,
      dataInicio: quarta18,
      intervaloHoras: 8,
      duracaoDias: 7,
      estoque: estoque,
    );

void main() {
  group('Cálculos de estoque', () {
    test('consumo diário considera frequência e dias da semana', () {
      expect(losartana().consumoDiario, 1);
      expect(amoxicilina().consumoDiario, 3);
      final segQuaSex = Medicamento(
        id: 3, nome: 'x', dosagem: '', hora: 9, minuto: 0,
        diasSemana: const {1, 3, 5}, estoque: 10, unidadesPorDose: 2,
      );
      expect(segQuaSex.consumoDiario, closeTo(6 / 7, 0.001));
    });

    test('limite do aviso = consumo de N dias (padrão 3)', () {
      expect(losartana().limiteAviso, 3);
      expect(amoxicilina(estoque: 30).limiteAviso, 9);
      expect(losartana(estoque: 3).estoqueBaixo, isTrue);
      expect(losartana(estoque: 4).estoqueBaixo, isFalse);
    });

    test('até quando dura o estoque e quantos dias', () {
      final m = losartana(estoque: 3);
      final agora = DateTime(2026, 11, 18, 7);
      expect(m.estoqueDuraAte(agora), DateTime(2026, 11, 20, 8));
      expect(m.diasDeEstoque(agora), 3);
    });

    test('se a dose de hoje já passou, conta a partir de amanhã', () {
      // 3 comprimidos às 09:00 (dose das 08:00 já passou): 19, 20 e 21.
      final m = losartana(estoque: 3);
      final agora = DateTime(2026, 11, 18, 9);
      expect(m.estoqueDuraAte(agora), DateTime(2026, 11, 21, 8));
      expect(m.diasDeEstoque(agora), 3);
    });

    test('5 comprimidos de 8 em 8 h dão para 2 dias', () {
      // A partir da 00:00 de quinta: 00, 08, 16 (quinta) + 00, 08 (sexta).
      final m = amoxicilina(estoque: 5);
      expect(m.diasDeEstoque(DateTime(2026, 11, 18, 23)), 2);
    });

    test('dias da semana: 2 cápsulas seg/qua/sex a partir de quarta', () {
      final m = Medicamento(
        id: 3, nome: 'Vitamina D', dosagem: '', hora: 9, minuto: 30,
        dataInicio: quarta18, diasSemana: const {1, 3, 5}, estoque: 2,
      );
      // Quarta 10:00 → próximas: sexta 20 e segunda 23.
      expect(m.estoqueDuraAte(DateTime(2026, 11, 18, 10)),
          DateTime(2026, 11, 23, 9, 30));
    });

    test('quanto falta para terminar o tratamento', () {
      final antes = DateTime(2026, 11, 18, 7);
      expect(amoxicilina(estoque: 15).unidadesAteOFim(antes), 21);
      expect(amoxicilina(estoque: 15).faltaParaOFim(antes), 6);
      expect(amoxicilina(estoque: 30).faltaParaOFim(antes), 0);
      expect(losartana().faltaParaOFim(antes), isNull); // uso contínuo
    });

    test('estoque menor que uma dose = acabou', () {
      expect(losartana(estoque: 3, porDose: 2).estoqueAcabou, isFalse);
      expect(losartana(estoque: 1, porDose: 2).estoqueAcabou, isTrue);
      expect(losartana(estoque: null).estoqueAcabou, isFalse);
    });

    test('texto com singular e plural da unidade', () {
      expect(losartana().descreverQuantidade(1), '1 comprimido');
      expect(losartana().descreverQuantidade(12), '12 comprimidos');
    });

    test('JSON: ida e volta e remédio antigo sem estoque', () {
      final m = losartana(estoque: 7, porDose: 2);
      expect(Medicamento.fromJson(m.toJson()).toJson(), m.toJson());
      final antigo = Medicamento.fromJson(
          {'id': 9, 'nome': 'x', 'hora': 8, 'minuto': 0});
      expect(antigo.controlaEstoque, isFalse);
      expect(antigo.unidadesPorDose, 1);
      expect(antigo.unidade, 'comprimido');
    });
  });

  group('EstoqueService', () {
    final servico = EstoqueService.instance;
    final repo = MedicamentoRepository.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await repo.carregar();
      await DoseRepository.instance.carregar();
    });

    test('desconta uma dose por comprovação', () async {
      await repo.salvar(losartana(estoque: 10, porDose: 2));
      expect(await servico.descontarDose(1), 2);
      expect(repo.porId(1)!.estoque, 8);
    });

    test('nunca fica negativo', () async {
      await repo.salvar(losartana(estoque: 1, porDose: 2));
      expect(await servico.descontarDose(1), 1);
      expect(repo.porId(1)!.estoque, 0);
    });

    test('remédio sem controle de estoque não muda', () async {
      await repo.salvar(losartana(estoque: null));
      expect(await servico.descontarDose(1), isNull);
      expect(repo.porId(1)!.estoque, isNull);
    });

    test('o aviso de "acabando" só dispara ao cruzar o limite', () {
      MudancaEstoque mudanca(int antes, int depois) => MudancaEstoque(
          losartana(estoque: antes), losartana(estoque: depois));
      expect(mudanca(5, 4).ficouBaixo, isFalse);
      expect(mudanca(4, 3).ficouBaixo, isTrue); // cruzou (limite = 3)
      expect(mudanca(3, 2).ficouBaixo, isFalse); // já estava baixo
      expect(mudanca(2, 32).ficouBaixo, isFalse); // reposição
      expect(mudanca(1, 0).mudouAcabou, isTrue);
      expect(mudanca(0, 30).mudouAcabou, isTrue);
    });

    test('repor soma ao estoque', () async {
      await repo.salvar(losartana(estoque: 2));
      final mudanca = await servico.repor(1, 30);
      expect(mudanca!.depois.estoque, 32);
      expect(repo.porId(1)!.estoque, 32);
    });

    test('excluir o comprovante devolve as unidades', () async {
      await repo.salvar(losartana(estoque: 9));
      final dose = Dose(
        id: 1,
        medicamentoId: 1,
        nomeMedicamento: 'Losartana',
        dosagem: '50 mg',
        horarioPrevisto: '08:00',
        dataHora: DateTime(2026, 11, 18, 8, 2),
        fotoPath: '/nao/existe.jpg',
        unidadesDescontadas: 1,
      );
      await DoseRepository.instance.registrar(dose);
      await DoseRepository.instance.remover(dose);
      expect(repo.porId(1)!.estoque, 10);
    });

    test('aviso de estoque tem payload próprio', () {
      expect(NotificationService.idEstoqueDoPayload('estoque:7'), 7);
      expect(NotificationService.idEstoqueDoPayload('dose:7'), isNull);
      expect(NotificationService.idDoPayload('estoque:7'), isNull);
    });
  });
}
