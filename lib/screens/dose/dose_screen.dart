import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/dose.dart';
import '../../models/medicamento.dart';
import '../../services/camera_service.dart';
import '../../services/dose_repository.dart';
import '../../services/medicamento_repository.dart';

/// Abre a comprovação de dose: se houver mais de um remédio,
/// pergunta qual está sendo tomado.
Future<void> abrirComprovacao(BuildContext context) async {
  final lista = MedicamentoRepository.instance.medicamentos;
  if (lista.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastre um remédio primeiro.')),
    );
    return;
  }

  final escolhido = lista.length == 1
      ? lista.first
      : await showModalBottomSheet<Medicamento>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Qual remédio você vai tomar?',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                for (final m in lista)
                  ListTile(
                    leading: const Icon(Icons.medication),
                    title: Text(m.nome),
                    subtitle: Text(m.dosagem),
                    trailing: Text(m.horario),
                    onTap: () => Navigator.pop(context, m),
                  ),
              ],
            ),
          ),
        );

  if (escolhido == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DoseScreen(medicamento: escolhido),
    ),
  );
}

/// Tela "Hora do remédio": o usuário fotografa a caixa ou o comprimido
/// para comprovar que tomou a dose.
class DoseScreen extends StatefulWidget {
  const DoseScreen({super.key, required this.medicamento});

  final Medicamento medicamento;

  @override
  State<DoseScreen> createState() => _DoseScreenState();
}

class _DoseScreenState extends State<DoseScreen> {
  XFile? _foto;
  bool _salvando = false;

  Future<void> _capturar({bool galeria = false}) async {
    try {
      final camera = CameraService.instance;
      final foto =
          galeria ? await camera.escolherDaGaleria() : await camera.tirarFoto();
      if (foto != null) setState(() => _foto = foto);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a câmera: $e')),
      );
    }
  }

  Future<void> _confirmar() async {
    final foto = _foto;
    if (foto == null) return;
    setState(() => _salvando = true);

    final m = widget.medicamento;
    final caminho = await CameraService.instance.salvarComprovante(foto);
    final agora = DateTime.now();

    await DoseRepository.instance.registrar(
      Dose(
        id: agora.millisecondsSinceEpoch,
        medicamentoId: m.id,
        nomeMedicamento: m.nome,
        dosagem: m.dosagem,
        horarioPrevisto: m.horario,
        dataHora: agora,
        fotoPath: caminho,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.sucesso,
        content: Text('Dose de ${m.nome} comprovada! ✅'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = widget.medicamento;
    final foto = _foto;

    return Scaffold(
      appBar: AppBar(title: const Text('Hora do remédio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabeçalho com o remédio
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(Icons.medication,
                    size: 48, color: scheme.onPrimaryContainer),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.nome,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${m.dosagem.isEmpty ? 'Dose' : m.dosagem} • ${m.horario}',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Área da foto
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: foto == null
                  ? InkWell(
                      onTap: _capturar,
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                size: 64, color: scheme.primary),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Fotografe a caixa ou o comprimido\n'
                                'para comprovar que tomou',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image.file(File(foto.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),

          if (foto == null) ...[
            FilledButton.icon(
              onPressed: _capturar,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tirar foto'),
            ),
            TextButton(
              onPressed: () => _capturar(galeria: true),
              child: const Text('Sem câmera? Escolher da galeria'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _salvando ? null : _confirmar,
              icon: _salvando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Confirmar que tomei'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _salvando ? null : _capturar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tirar outra foto'),
            ),
          ],
        ],
      ),
    );
  }
}
