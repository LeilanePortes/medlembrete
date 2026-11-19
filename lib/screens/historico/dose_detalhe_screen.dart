import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/dose.dart';
import '../../services/detector_movimento.dart';
import '../../services/dose_repository.dart';
import '../../services/location_service.dart';
import '../../widgets/foto_comprovante.dart';
import '../../widgets/mapa_local.dart';

/// Comprovante completo de uma dose: foto, coordenadas, mapa e
/// estado do celular — tudo na mesma tela (desafio extra).
class DoseDetalheScreen extends StatelessWidget {
  const DoseDetalheScreen({super.key, required this.dose});

  final Dose dose;

  String _textoLocalizacao() {
    if (!dose.temLocalizacao) return 'O GPS não estava disponível';
    final coordenadas = 'Lat ${dose.latitude!.toStringAsFixed(6)}  •  '
        'Lon ${dose.longitude!.toStringAsFixed(6)}';
    final distancia = dose.distanciaCasaMetros;
    if (distancia == null) return coordenadas;
    return '$coordenadas\n${LocationService.formatarDistancia(distancia)} da casa';
  }

  Future<void> _excluir(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir comprovante?'),
        content: const Text('A foto também será apagada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await DoseRepository.instance.remover(dose);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprovante'),
        actions: [
          IconButton(
            tooltip: 'Excluir',
            onPressed: () => _excluir(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Hero(
              tag: 'foto-${dose.id}',
              child: FotoComprovante(referencia: dose.fotoPath),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.medication),
                  title: Text(dose.nomeMedicamento),
                  subtitle: Text(dose.dosagem.isEmpty ? '—' : dose.dosagem),
                ),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Tomado em'),
                  subtitle: Text(formatarDataHora(dose.dataHora)),
                ),
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: const Text('Horário previsto'),
                  subtitle: Text(dose.horarioPrevisto),
                ),
                ListTile(
                  leading: Icon(
                      dose.emCasa == true ? Icons.home : Icons.location_on),
                  title: Text(dose.descricaoLocal),
                  subtitle: Text(_textoLocalizacao()),
                ),
                ListTile(
                  leading: const Icon(Icons.sensors),
                  title: const Text('Estado do celular'),
                  subtitle: Text(dose.estadoCelular?.rotulo ?? 'Não registrado'),
                ),
              ],
            ),
          ),
          if (dose.temLocalizacao) ...[
            const SizedBox(height: 16),
            MapaLocal(
              latitude: dose.latitude!,
              longitude: dose.longitude!,
              casa: LocationService.instance.casa,
            ),
          ],
        ],
      ),
    );
  }
}
