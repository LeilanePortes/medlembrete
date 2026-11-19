import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../services/location_service.dart';

/// Mapa (OpenStreetMap) com a posição atual e o raio da casa.
///
/// Precisa de internet para carregar os "tiles" (imagens) do mapa.
class MapaLocal extends StatelessWidget {
  const MapaLocal({
    super.key,
    required this.latitude,
    required this.longitude,
    this.casa,
    this.altura = 220,
    this.zoom = 16,
  });

  final double latitude;
  final double longitude;
  final Coordenada? casa;
  final double altura;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final posicao = LatLng(latitude, longitude);
    final casa = this.casa;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: altura,
        child: FlutterMap(
          // Recria o mapa quando a posição muda, recentralizando.
          key: ValueKey('$latitude,$longitude'),
          options: MapOptions(initialCenter: posicao, initialZoom: zoom),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: AppConstants.pacoteApp,
            ),
            if (casa != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(casa.latitude, casa.longitude),
                    radius: LocationService.raioCasaMetros,
                    useRadiusInMeter: true,
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderColor: scheme.primary,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (casa != null)
                  Marker(
                    point: LatLng(casa.latitude, casa.longitude),
                    child: Icon(Icons.home, color: scheme.primary, size: 28),
                  ),
                Marker(
                  point: posicao,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: const Icon(Icons.location_pin,
                      color: Colors.red, size: 40),
                ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('© OpenStreetMap'),
            ),
          ],
        ),
      ),
    );
  }
}
