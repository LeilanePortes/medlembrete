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

  /// Máximo de doses agendadas de uma vez para tratamentos com fim
  /// (o iOS aceita até 64 pendentes). O app completa a lista sempre que
  /// é aberto (ver [reagendarTodos]).
  static const int maxDosesAgendadas = 60;

  /// IDs das notificações de um remédio: cada dose agendada precisa de
  /// um ID próprio. [n] vai de 0 a 199 (199 = notificação de teste).
  static int idNotificacao(int medicamentoId, int n) =>
      (medicamentoId * 200 + n) & 0x7fffffff;

  static const int _nTeste = 199;

  /// Agenda os lembretes do remédio conforme a agenda dele:
  ///
  /// - **Uso contínuo, todos os dias:** uma notificação por horário do dia,
  ///   repetindo diariamente (`DateTimeComponents.time`).
  /// - **Uso contínuo, alguns dias da semana:** uma por horário e por dia
  ///   da semana, repetindo semanalmente (`dayOfWeekAndTime`).
  /// - **Tratamento com fim (ex.: 7 dias):** cada dose é agendada uma a
  ///   uma até o fim (até [maxDosesAgendadas] por vez).
  Future<void> agendarLembretes(Medicamento m) async {
    if (!_inicializado) return;
    await cancelarLembretes(m.id);
    if (!m.ativo) return;

    if (kIsWeb) {
      _agendarProximaNaWeb(m);
      return;
    }

    final agora = DateTime.now();
    final modo = await _modoAgendamento();
    final payload = '$prefixoDose${m.id}';

    Future<void> agendar(int n, DateTime quando, DateTimeComponents? repetir) =>
        _plugin.zonedSchedule(
          id: idNotificacao(m.id, n),
          title: _titulo(m),
          body: _corpo(m),
          scheduledDate: tz.TZDateTime.from(quando, tz.local),
          notificationDetails: _detalhes,
          androidScheduleMode: modo,
          matchDateTimeComponents: repetir,
          payload: payload,
        );

    if (!m.continuo) {
      final doses = m
          .ocorrenciasEntre(agora, m.fim!)
          .take(maxDosesAgendadas)
          .toList();
      for (var i = 0; i < doses.length; i++) {
        await agendar(100 + i, doses[i], null);
      }
      debugPrint('Lembretes agendados: ${m.nome} (${doses.length} doses)');
      return;
    }

    // Uso contínuo: a 1ª ocorrência de cada horário (e dia da semana)
    // é agendada com repetição; o sistema repete sozinho depois.
    final minutos = m.minutosDoDia;
    final dias = m.todaSemana ? const [0] : (m.diasSemana.toList()..sort());
    for (var s = 0; s < minutos.length; s++) {
      for (final dia in dias) {
        final primeira = _primeiraOcorrencia(m, minutos[s], dia, agora);
        if (primeira == null) continue;
        await agendar(
          s * 8 + dia,
          primeira,
          dia == 0
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
    debugPrint('Lembretes agendados: ${m.nome} ${m.horariosDoDia} '
        '(${m.descricaoDias})');
  }

  /// Primeira dose de [m] no minuto do dia [minutoDoDia] (e no dia da
  /// semana [diaSemana], se diferente de 0) depois de [agora].
  static DateTime? _primeiraOcorrencia(
      Medicamento m, int minutoDoDia, int diaSemana, DateTime agora) {
    final proximas = m.ocorrenciasEntre(
      agora.add(const Duration(microseconds: 1)),
      DateTime(agora.year, agora.month, agora.day + 8),
    );
    final inicio = m.inicio;
    // Se o tratamento ainda não começou, procura a partir do início.
    final lista = (inicio != null && inicio.isAfter(agora))
        ? m.ocorrenciasEntre(
            inicio, DateTime(inicio.year, inicio.month, inicio.day + 8))
        : proximas;
    for (final t in lista) {
      if (t.hour * 60 + t.minute != minutoDoDia) continue;
      if (diaSemana != 0 && t.weekday != diaSemana) continue;
      return t;
    }
    return null;
  }

  /// Agenda um lembrete único daqui a [atraso], útil para testar o
  /// recurso sem esperar o horário real.
  Future<void> agendarTeste(
    Medicamento m, {
    Duration atraso = const Duration(seconds: 10),
  }) async {
    if (!_inicializado) return;
    final id = idNotificacao(m.id, _nTeste);
    if (kIsWeb) {
      _timersWeb.remove(id)?.cancel();
      _timersWeb[id] = Timer(atraso, () {
        _timersWeb.remove(id);
        _mostrarLembrete(id, m);
      });
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
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

  Future<void> _mostrarLembrete(int id, Medicamento m) => mostrarAgora(
        id: id,
        titulo: _titulo(m),
        corpo: _corpo(m),
        payload: '$prefixoDose${m.id}',
      );

  /// Cancela todos os lembretes agendados de um remédio
  /// (exceto a notificação de teste).
  Future<void> cancelarLembretes(int medicamentoId) async {
    if (!_inicializado) return;
    if (kIsWeb) {
      _timersWeb.remove(idNotificacao(medicamentoId, 0))?.cancel();
      return;
    }
    final teste = idNotificacao(medicamentoId, _nTeste);
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (idDoPayload(p.payload) == medicamentoId && p.id != teste) {
        await _plugin.cancel(id: p.id);
      }
    }
  }

  /// O `setTimeout` do navegador estoura com esperas acima de ~24 dias.
  static const Duration _esperaMaximaWeb = Duration(days: 20);

  /// Web: agenda só a PRÓXIMA dose com um Timer; quando ela dispara,
  /// agenda a seguinte.
  void _agendarProximaNaWeb(Medicamento m) {
    final id = idNotificacao(m.id, 0);
    _timersWeb.remove(id)?.cancel();
    final agora = DateTime.now();
    final proxima = m.proximaOcorrencia(agora);
    if (proxima == null) return; // tratamento terminou

    final espera = proxima.difference(agora);
    if (espera > _esperaMaximaWeb) {
      // Tratamento que começa daqui a muito tempo: confere de novo depois.
      _timersWeb[id] = Timer(_esperaMaximaWeb, () => _agendarProximaNaWeb(m));
      return;
    }
    _timersWeb[id] = Timer(espera, () {
      _mostrarLembrete(id, m);
      _agendarProximaNaWeb(m);
    });
    debugPrint('Próximo lembrete (web): ${m.nome} em ${proxima.toLocal()}');
  }

  /// Reagenda todos os lembretes (chamado ao abrir o app).
  Future<void> reagendarTodos(Iterable<Medicamento> medicamentos) async {
    for (final m in medicamentos) {
      await agendarLembretes(m);
    }
  }

  /// Extrai o id do remédio de um payload `dose:<id>`.
  static int? idDoPayload(String? payload) {
    if (payload == null || !payload.startsWith(prefixoDose)) return null;
    return int.tryParse(payload.substring(prefixoDose.length));
  }
}
