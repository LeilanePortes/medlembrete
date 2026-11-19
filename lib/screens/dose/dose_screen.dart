import 'package:flutter/material.dart';

import '../../models/medicamento.dart';

/// Tela aberta ao tocar na notificação: "Hora do remédio".
class DoseScreen extends StatelessWidget {
  const DoseScreen({super.key, required this.medicamento});

  final Medicamento medicamento;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = medicamento;

    return Scaffold(
      appBar: AppBar(title: const Text('Hora do remédio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.medication,
                    size: 64, color: scheme.onPrimaryContainer),
                const SizedBox(height: 12),
                Text(
                  m.nome,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                if (m.dosagem.isNotEmpty)
                  Text(m.dosagem,
                      style: TextStyle(color: scheme.onPrimaryContainer)),
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.alarm, size: 18),
                  label: Text('Horário: ${m.horario}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Comprovar com foto (Sprint 2)'),
          ),
        ],
      ),
    );
  }
}
