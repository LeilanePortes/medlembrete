import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicamento.dart';

/// Centraliza tudo o que envolve notificações locais:
/// inicialização, permissões, agendamento diário e toques do usuário.
///
/// No navegador (Chrome) o plugin não agenda notificações futuras
/// (`zonedSchedule` não existe na web). Por isso, na web, o agendamento é
/// feito com um [Timer] do próprio app: a notificação aparece no horário
/// enquanto a aba do MedLembrete estiver aberta (pode estar minimizada).
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
    // Na web, a notificação fica na tela até o usuário interagir.
    web: WebNotificationDetails(requireInteraction: true),
  );

  /// Lembretes agendados na web (id da notificação -> timer).
  final Map<int, Timer> _timersWeb = {};

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
      web: WebInitializationSettings(),
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

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  WebFlutterLocalNotificationsPlugin? get _web => kIsWeb
      ? _plugin
            .resolvePlatformSpecificImplementation<
              WebFlutterLocalNotificationsPlugin
            >()
      : null;

  /// Na web, o navegador só deixa pedir a permissão a partir de um
  /// clique do usuário. Este getter diz se ainda falta pedir.
  bool get precisaPermissaoWeb =>
      _web != null &&
      _web!.permissionStatus != WebNotificationPermission.granted;

  /// true se o usuário bloqueou as notificações no navegador.
  bool get bloqueadaNaWeb =>
      _web?.permissionStatus == WebNotificationPermission.denied;

  /// Pede permissão para exibir notificações (Android 13+ e iOS)
  /// e para alarmes exatos (Android 12+), usados no horário certo do remédio.
  ///
  /// Na web, chame apenas a partir de um clique (botão).
  Future<bool> solicitarPermissoes() async {
    if (!_inicializado) return false;
    final web = _web;
    if (web != null) {
      return await web.requestNotificationsPermission() ?? false;
    }
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

    if (kIsWeb) {
      _agendarNaWeb(
        id: m.id,
        quando: proximoHorario(DateTime.now(), m.hora, m.minuto),
        medicamento: m,
        diario: true,
      );
      debugPrint('Lembrete agendado (web): ${m.nome} às ${m.horario}');
      return;
    }

    final agora = tz.TZDateTime.now(tz.local);
    var horario = tz.TZDateTime(
      tz.local,
      agora.year,
      agora.month,
      agora.day,
      m.hora,
      m.minuto,
    );
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
  Future<void> agendarTeste(
    Medicamento m, {
    Duration atraso = const Duration(seconds: 10),
  }) async {
    if (!_inicializado) return;
    if (kIsWeb) {
      _agendarNaWeb(
        id: m.id + 1,
        quando: DateTime.now().add(atraso),
        medicamento: m,
      );
      return;
    }
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
    try {
      await _plugin.show(
        id: id,
        title: titulo,
        body: corpo,
        notificationDetails: _detalhes,
        payload: payload,
      );
    } catch (e) {
      // Na web, falha se o usuário ainda não permitiu as notificações.
      debugPrint('Não foi possível mostrar a notificação: $e');
    }
  }

  Future<void> cancelar(int id) async {
    if (!_inicializado) return;
    _timersWeb.remove(id)?.cancel();
    await _plugin.cancel(id: id);
  }

  /// Web: agenda a notificação com um Timer. Se [diario], ao disparar
  /// já agenda a do dia seguinte.
  void _agendarNaWeb({
    required int id,
    required DateTime quando,
    required Medicamento medicamento,
    bool diario = false,
  }) {
    _timersWeb.remove(id)?.cancel();
    final espera = quando.difference(DateTime.now());
    _timersWeb[id] = Timer(espera.isNegative ? Duration.zero : espera, () {
      _timersWeb.remove(id);
      mostrarAgora(
        id: id,
        titulo: _titulo(medicamento),
        corpo: _corpo(medicamento),
        payload: '$prefixoDose${medicamento.id}',
      );
      if (diario) {
        _agendarNaWeb(
          id: id,
          quando: quando.add(const Duration(days: 1)),
          medicamento: medicamento,
          diario: true,
        );
      }
    });
  }

  /// Próxima ocorrência de [hora]:[minuto] a partir de [agora]
  /// (hoje, se ainda não passou; senão amanhã).
  static DateTime proximoHorario(DateTime agora, int hora, int minuto) {
    final hoje = DateTime(agora.year, agora.month, agora.day, hora, minuto);
    return hoje.isAfter(agora) ? hoje : hoje.add(const Duration(days: 1));
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
