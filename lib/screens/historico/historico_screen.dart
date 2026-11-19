import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/dose.dart';
import '../../services/detector_movimento.dart';
import '../../services/dose_repository.dart';
import '../../widgets/placeholder_view.dart';
import 'dose_detalhe_screen.dart';

/// Histórico de doses comprovadas com foto.
class HistoricoScreen extends StatelessWidget {
  const HistoricoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repositorio = DoseRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de doses')),
      body: ListenableBuilder(
        listenable: repositorio,
        builder: (context, _) {
          final doses = repositorio.doses;
          if (doses.isEmpty) {
            return const PlaceholderView(
              icon: Icons.photo_library_outlined,
              mensagem: 'Nenhuma dose comprovada ainda.\n'
                  'Toque na notificação ou em "Comprovação" na tela inicial.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _DoseTile(dose: doses[i]),
          );
        },
      ),
    );
  }
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.dose});

  final Dose dose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DoseDetalheScreen(dose: dose),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Hero(
              tag: 'foto-${dose.id}',
              child: Image.file(
                File(dose.fotoPath),
                width: 96,
                height: 120,
                fit: BoxFit.cover,
                cacheWidth: 200,
                errorBuilder: (_, _, _) => Container(
                  width: 96,
                  height: 120,
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dose.nomeMedicamento,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(formatarDataHora(dose.dataHora),
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  Text('Previsto: ${dose.horarioPrevisto}',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Etiqueta(
                        icone: dose.emCasa == true
                            ? Icons.home
                            : Icons.location_on_outlined,
                        texto: dose.descricaoLocal,
                      ),
                      if (dose.estadoCelular != null)
                        _Etiqueta(
                          icone: Icons.sensors,
                          texto: dose.estadoCelular!.rotulo,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(texto,
              style: TextStyle(
                  fontSize: 12, color: scheme.onSecondaryContainer)),
        ],
      ),
    );
  }
}
