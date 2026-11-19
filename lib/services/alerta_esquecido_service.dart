import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'detector_movimento.dart';
import 'movimento_service.dart';
import 'notification_service.dart';
import 'resumo_doses.dart';

/// Desafio extra: notificação disparada por uma CONDIÇÃO.
///
/// Quando o acelerômetro indica que o celular ficou parado por mais
/// tempo que o limite (provavelmente esquecido), o app envia uma
/// notificação lembrando das doses pendentes.
class AlertaEsquecidoService extends ChangeNotifier {
  AlertaEsquecidoService._();
  static final AlertaEsquecidoService instance = AlertaEsquecidoService._();

  static const int idNotificacao = 900001;
  static const _chaveAtivo = 'alerta_esquecido_ativo';
  static const _chaveSegundos = 'alerta_esquecido_segundos';

  /// Opções de tempo (em segundos). 30 s é ótimo para a apresentação.
  static const List<int> opcoesSegundos = [30, 60, 300, 900];

  bool _ativo = true;
  int _segundos = 30;
  EstadoMovimento? _estadoAnterior;
  DateTime? ultimoAlerta;

  bool get ativo => _ativo;
  int get segundos => _segundos;

  Future<void> iniciar() async {
    final prefs = await SharedPreferences.getInstance();
    _ativo = prefs.getBool(_chaveAtivo) ?? true;
    _segundos = prefs.getInt(_chaveSegundos) ?? 30;
    _aplicarLimite();
    MovimentoService.instance.addListener(_verificar);
    notifyListeners();
  }

  Future<void> definirAtivo(bool valor) async {
    _ativo = valor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveAtivo, valor);
    notifyListeners();
  }

  Future<void> definirSegundos(int valor) async {
    _segundos = valor;
    _aplicarLimite();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chaveSegundos, valor);
    notifyListeners();
  }

  void _aplicarLimite() {
    MovimentoService.instance.detector.tempoEsquecido =
        Duration(seconds: _segundos);
  }

  /// Chamado a cada leitura do acelerômetro: só age na TRANSIÇÃO
  /// para "esquecido", para não repetir a notificação.
  void _verificar() {
    final estado = MovimentoService.instance.estado;
    final virouEsquecido = estado == EstadoMovimento.esquecido &&
        _estadoAnterior != EstadoMovimento.esquecido;
    _estadoAnterior = estado;
    if (!virouEsquecido || !_ativo) return;

    final pendentes = ResumoDoses.pendentesHoje();
    final corpo = pendentes.isEmpty
        ? 'Seu celular está parado há um tempo. '
            'Leve-o com você para não perder o próximo lembrete!'
        : 'Você ainda não comprovou: '
            '${pendentes.map((m) => m.nome).join(', ')}. '
            'Pegue o celular e tire a foto da dose.';

    ultimoAlerta = DateTime.now();
    NotificationService.instance.mostrarAgora(
      id: idNotificacao,
      titulo: '📱 Celular esquecido?',
      corpo: corpo,
      payload: pendentes.isEmpty
          ? null
          : '${NotificationService.prefixoDose}${pendentes.first.id}',
    );
    notifyListeners();
  }
}
