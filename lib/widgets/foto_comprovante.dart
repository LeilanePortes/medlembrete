import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/camera_service.dart';

/// Exibe a foto de um comprovante, venha ela de um arquivo (celular)
/// ou de uma data URL guardada no navegador (Chrome).
class FotoComprovante extends StatefulWidget {
  const FotoComprovante({
    super.key,
    required this.referencia,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  /// Caminho do arquivo ou data URL (`Dose.fotoPath`).
  final String referencia;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  State<FotoComprovante> createState() => _FotoComprovanteState();
}

class _FotoComprovanteState extends State<FotoComprovante> {
  /// Bytes decodificados uma única vez (evita piscar ao redesenhar).
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decodificar();
  }

  @override
  void didUpdateWidget(FotoComprovante antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.referencia != widget.referencia) _decodificar();
  }

  void _decodificar() {
    _bytes = CameraService.ehDataUrl(widget.referencia)
        ? CameraService.bytesDoDataUrl(widget.referencia)
        : null;
  }

  Widget _semFoto(BuildContext context, Object _, StackTrace? _) => Container(
        width: widget.width,
        height: widget.height ?? 200,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      );

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
        errorBuilder: _semFoto,
      );
    }
    return Image.file(
      File(widget.referencia),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      errorBuilder: _semFoto,
    );
  }
}
