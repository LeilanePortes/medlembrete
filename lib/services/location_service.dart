import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Situação da leitura do GPS.
enum StatusGps { ok, servicoDesligado, permissaoNegada, permissaoNegadaSempre, erro }

/// Resultado de uma tentativa de obter a localização.
class LeituraGps {
  const LeituraGps(this.status, {this.posicao, this.mensagem});

  final StatusGps status;
  final Position? posicao;
  final String? mensagem;

  bool get sucesso => status == StatusGps.ok && posicao != null;
}

/// Um ponto geográfico simples (usado para guardar a "casa").
class Coordenada {
  const Coordenada(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  String toString() =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// Obtém a posição pelo GPS e decide se o usuário está em casa ou fora.
class LocationService extends ChangeNotifier {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Distância máxima (em metros) para considerar "em casa".
  /// 100 m cobre a imprecisão normal do GPS dentro de casa/prédio.
  static const double raioCasaMetros = 100;

  static const _chaveLat = 'casa_lat';
  static const _chaveLon = 'casa_lon';

  Coordenada? _casa;
  Coordenada? get casa => _casa;

  Future<void> carregarCasa() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_chaveLat);
    final lon = prefs.getDouble(_chaveLon);
    _casa = (lat != null && lon != null) ? Coordenada(lat, lon) : null;
    notifyListeners();
  }

  Future<void> definirCasa(Coordenada coordenada) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_chaveLat, coordenada.latitude);
    await prefs.setDouble(_chaveLon, coordenada.longitude);
    _casa = coordenada;
    notifyListeners();
  }

  Future<void> limparCasa() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveLat);
    await prefs.remove(_chaveLon);
    _casa = null;
    notifyListeners();
  }

  /// Fluxo completo: verifica o serviço de localização, pede a permissão
  /// (se necessário) e lê a posição atual.
  Future<LeituraGps> obterPosicaoAtual() async {
    try {
      // 1. O GPS do aparelho está ligado?
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LeituraGps(
          StatusGps.servicoDesligado,
          mensagem: 'A localização do celular está desligada.',
        );
      }

      // 2. O app tem permissão? Se não, pede ao usuário.
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied) {
        return const LeituraGps(
          StatusGps.permissaoNegada,
          mensagem: 'Permissão de localização negada.',
        );
      }
      if (permissao == LocationPermission.deniedForever) {
        return const LeituraGps(
          StatusGps.permissaoNegadaSempre,
          mensagem: 'Permissão negada permanentemente. '
              'Libere nas configurações do app.',
        );
      }

      // 3. Lê a posição com alta precisão (limite de 15 s).
      try {
        final posicao = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        return LeituraGps(StatusGps.ok, posicao: posicao);
      } catch (_) {
        // Sem sinal a tempo (ex.: dentro de prédio): usa a última conhecida.
        final ultima = await Geolocator.getLastKnownPosition();
        if (ultima != null) return LeituraGps(StatusGps.ok, posicao: ultima);
        rethrow;
      }
    } catch (e) {
      return LeituraGps(StatusGps.erro, mensagem: 'Erro ao ler o GPS: $e');
    }
  }

  Future<void> abrirConfiguracoes(StatusGps status) async {
    if (status == StatusGps.servicoDesligado) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Distância em metros entre a posição e a casa (null se não há casa).
  double? distanciaAteCasa(double latitude, double longitude) {
    final c = _casa;
    if (c == null) return null;
    return Geolocator.distanceBetween(
        latitude, longitude, c.latitude, c.longitude);
  }

  /// true = em casa, false = fora, null = casa não definida.
  bool? estaEmCasa(double latitude, double longitude) {
    final distancia = distanciaAteCasa(latitude, longitude);
    return distancia == null ? null : dentroDoRaio(distancia);
  }

  static bool dentroDoRaio(double distanciaMetros) =>
      distanciaMetros <= raioCasaMetros;

  /// "35 m" ou "2,4 km".
  static String formatarDistancia(double metros) {
    if (metros < 1000) return '${metros.round()} m';
    return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
}
