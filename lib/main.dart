import 'package:flutter/material.dart';

import 'app.dart';
import 'services/medicamento_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega os remédios salvos e prepara as notificações antes de abrir o app.
  final repositorio = MedicamentoRepository.instance;
  await repositorio.carregar();

  final notificacoes = NotificationService.instance;
  await notificacoes.inicializar();
  await notificacoes.reagendarTodos(repositorio.medicamentos);

  runApp(const MedLembreteApp());
}
