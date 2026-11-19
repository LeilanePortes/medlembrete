import 'package:flutter_test/flutter_test.dart';

import 'package:medlembrete/app.dart';

void main() {
  testWidgets('App abre na tela inicial com as 4 funcionalidades',
      (tester) async {
    await tester.pumpWidget(const MedLembreteApp());

    expect(find.text('MedLembrete'), findsOneWidget);
    expect(find.text('Lembretes'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Comprovação'), findsOneWidget);
    expect(find.text('Localização'), findsWidgets);
    expect(find.text('Movimento'), findsWidgets);
  });
}
