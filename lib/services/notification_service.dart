import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicamento.dart';

/// Centraliza tudo o que envolve notificações locais:
/// inicialização, permissões, agendamento diário e toques do usuário.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Prefixo do payload das notificações de remédio: `dose:<id>`.
  static const String prefixoDose = 'dose:';

  static const _canalLembretes = AndroidNotificationDetails(
    'lembretes_medicacao',
    'Lembretes de medicação',
    channelDescription: 'Avisa o horário de tomar cada remédio',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    ticker: 'Hora do remédio',
  );

  static const _detalhes = NotificationDetails(
    android: _canalLembretes,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
    ),
  );

  final StreamController<String?> _toques =
      StreamController<String?>.broadcast();

  /// Emite o payload sempre que o usuário toca em uma notificação
  /// com o app aberto (ou em segundo plano).
  Stream<String?> get toques => _toques.stream;

  /// Payload da notificação que abriu o app (app estava fechado).
  String? payloadDeAbertura;

  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado) return;

    // 1. Fuso horário: necessário para agendar no horário local correto.
    tz.initializeTimeZones();
    try {
      final fuso = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(fuso.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    // 2. Plugin. No iOS as permissões são pedidas depois, manualmente.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notificacao'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (resposta) =>
          _toques.add(resposta.payload),
    );

    // 3. O app foi aberto tocando em uma notificação?
    final abertura = await _plugin.getNotificationAppLaunchDetails();
    if (abertura?.didNotificationLaunchApp ?? false) {
      payloadDeAbertura = abertura!.notificationResponse?.payload;
    }

    _inicializado = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Pede permissão para exibir notificações (Android 13+ e iOS)
  /// e para alarmes exatos (Android 12+), usados no horário certo do remédio.
  Future<bool> solicitarPermissoes() async {
    if (!_inicializado) return false;
    final android = _android;
    if (android != null) {
      final notificacoes = await android.requestNotificationsPermission();
      final exato = await android.canScheduleExactNotifications() ?? true;
      if (!exato) await android.requestExactAlarmsPermission();
      return notificacoes ?? false;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Usa alarme exato se o usuário permitiu; senão, um agendamento
  /// aproximado (o Android pode atrasar alguns minutos).
  Future<AndroidScheduleMode> _modoAgendamento() async {
    final exato = await _android?.canScheduleExactNotifications() ?? true;
    return exato
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  String _titulo(Medicamento m) => '💊 Hora do remédio: ${m.nome}';
  String _corpo(Medicamento m) =>
      'Tome ${m.dosagem.isEmpty ? 'sua dose' : m.dosagem} e '
      'toque aqui para comprovar com uma foto.';

  /// Agenda o lembrete para repetir todos os dias no horário do remédio.
  Future<void> agendarLembreteDiario(Medicamento m) async {
    if (!_inicializado) return;
    await cancelar(m.id);
    if (!m.ativo) return;

    final agora = tz.TZDateTime.now(tz.local);
    var horario = tz.TZDateTime(
        tz.local, agora.year, agora.month, agora.day, m.hora, m.minuto);
    if (!horario.isAfter(agora)) {
      horario = horario.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: m.id,
      title: _titulo(m),
      body: _corpo(m),
      scheduledDate: horario,
      notificationDetails: _detalhes,
      androidScheduleMode: await _modoAgendamento(),
      // Repete diariamente comparando apenas hora e minuto.
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '$prefixoDose${m.id}',
    );
    debugPrint('Lembrete agendado: ${m.nome} às ${m.horario}');
  }

  /// Agenda um lembrete único daqui a [atraso] — útil para demonstrar
  /// o recurso na apresentação sem esperar o horário real.
  Future<void> agendarTeste(Medicamento m,
      {Duration atraso = const Duration(seconds: 10)}) async {
    if (!_inicializado) return;
    await _plugin.zonedSchedule(
      id: m.id + 1, // não sobrescreve o lembrete diário
      title: _titulo(m),
      body: _corpo(m),
      scheduledDate: tz.TZDateTime.now(tz.local).add(atraso),
      notificationDetails: _detalhes,
      androidScheduleMode: await _modoAgendamento(),
      payload: '$prefixoDose${m.id}',
    );
  }

  /// Mostra uma notificação imediatamente.
  Future<void> mostrarAgora({
    required int id,
    required String titulo,
    required String corpo,
    String? payload,
  }) async {
    if (!_inicializado) return;
    await _plugin.show(
      id: id,
      title: titulo,
      body: corpo,
      notificationDetails: _detalhes,
      payload: payload,
    );
  }

  Future<void> cancelar(int id) async {
    if (!_inicializado) return;
    await _plugin.cancel(id: id);
  }

  /// Reagenda todos os lembretes (chamado ao abrir o app).
  Future<void> reagendarTodos(Iterable<Medicamento> medicamentos) async {
    for (final m in medicamentos) {
      await agendarLembreteDiario(m);
    }
  }

  /// Extrai o id do remédio de um payload `dose:<id>`.
  static int? idDoPayload(String? payload) {
    if (payload == null || !payload.startsWith(prefixoDose)) return null;
    return int.tryParse(payload.substring(prefixoDose.length));
  }
}
