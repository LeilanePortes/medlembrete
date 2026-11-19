import 'package:flutter/material.dart';

import 'app.dart';
import 'services/alerta_esquecido_service.dart';
import 'services/dose_repository.dart';
import 'services/location_service.dart';
import 'services/medicamento_repository.dart';
import 'services/movimento_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega os remédios salvos e prepara as notificações antes de abrir o app.
  final repositorio = MedicamentoRepository.instance;
  await repositorio.carregar();
  await DoseRepository.instance.carregar();
  await LocationService.instance.carregarCasa();

  final notificacoes = NotificationService.instance;
  await notificacoes.inicializar();
  await notificacoes.reagendarTodos(repositorio.medicamentos);

  // Começa a ler o acelerômetro (X, Y, Z) enquanto o app estiver aberto.
  MovimentoService.instance.iniciar();
  // Desafio extra: notifica quando o celular parece esquecido.
  await AlertaEsquecidoService.instance.iniciar();

  runApp(const MedLembreteApp());
}
