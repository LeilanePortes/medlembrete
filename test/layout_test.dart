import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medlembrete/app.dart';
import 'package:medlembrete/models/medicamento.dart';
import 'package:medlembrete/screens/medicamentos/medicamento_form_screen.dart';
import 'package:medlembrete/services/dose_repository.dart';
import 'package:medlembrete/services/medicamento_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Garante que as telas cabem do celular pequeno (320 px) ao Chrome no PC
/// (1280 px) sem a faixa
/// "OVERFLOWED" — qualquer estouro de layout faz o teste falhar.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MedicamentoRepository.instance.carregar();
    await DoseRepository.instance.carregar();
    final hoje = DateTime.now();
    await MedicamentoRepository.instance.salvar(
      Medicamento(
        id: 1,
        nome: 'Amoxicilina',
        dosagem: '500 mg',
        hora: 8,
        minuto: 0,
        dataInicio: DateTime(hoje.year, hoje.month, hoje.day),
        intervaloHoras: 8,
        duracaoDias: 7,
        estoque: 2, // baixo: mostra o aviso e a previsão
      ),
    );
    await MedicamentoRepository.instance.salvar(
      Medicamento(
        id: 2,
        nome: 'Vitamina D',
        dosagem: '1 cápsula',
        hora: 21,
        minuto: 30,
        dataInicio: DateTime(hoje.year, hoje.month, hoje.day),
        diasSemana: const {1, 3, 5},
      ),
    );
  });

  void tamanho(WidgetTester tester, Size tela) {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final tela in const [Size(320, 640), Size(360, 740), Size(1280, 800)]) {
    testWidgets('abas principais cabem na tela ${tela.width.toInt()}px', (
      tester,
    ) async {
      tamanho(tester, tela);
      await tester.pumpWidget(const MedLembreteApp());
      await tester.pump();

      for (final aba in [
        'Remédios',
        'Histórico',
        'Local',
        'Movimento',
        'Início',
      ]) {
        await tester.tap(find.text(aba).last);
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('formulário do remédio cabe na tela ${tela.width.toInt()}px', (
      tester,
    ) async {
      tamanho(tester, tela);
      await tester.pumpWidget(
        MaterialApp(
          home: MedicamentoFormScreen(
            medicamento: MedicamentoRepository.instance.porId(1),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
