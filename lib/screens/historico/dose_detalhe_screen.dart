import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/dose.dart';
import '../../services/dose_repository.dart';

/// Comprovante completo de uma dose: foto + informações.
class DoseDetalheScreen extends StatelessWidget {
  const DoseDetalheScreen({super.key, required this.dose});

  final Dose dose;

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
              child: Image.file(File(dose.fotoPath), fit: BoxFit.cover),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
