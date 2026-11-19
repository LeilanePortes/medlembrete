import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/espelhar_foto.dart';

/// Câmera dentro do app, usada no navegador (Chrome).
///
/// Na web, o image_picker apenas abre o seletor de arquivos; para
/// fotografar de verdade usamos o pacote `camera`, que liga a webcam
/// (o Chrome pede a permissão de CÂMERA na primeira vez).
///
/// Devolve a foto tirada (XFile) com `Navigator.pop`.
class WebcamScreen extends StatefulWidget {
  const WebcamScreen({super.key});

  @override
  State<WebcamScreen> createState() => _WebcamScreenState();
}

class _WebcamScreenState extends State<WebcamScreen> {
  List<CameraDescription> _cameras = [];
  int _indice = 0;
  CameraController? _controller;
  String? _erro;
  bool _fotografando = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _erro = 'Nenhuma câmera encontrada neste dispositivo.');
        return;
      }
      // Prefere a câmera traseira (celular); no PC só existe a webcam.
      final traseira = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back);
      await _abrir(traseira >= 0 ? traseira : 0);
    } on CameraException catch (e) {
      _mostrarErro(e);
    }
  }

  Future<void> _abrir(int indice) async {
    final anterior = _controller;
    setState(() {
      _controller = null;
      _indice = indice;
    });
    await anterior?.dispose();

    // 720x480: boa para ler a caixa do remédio e leve para guardar.
    final controller = CameraController(
      _cameras[indice],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      await controller.dispose();
      _mostrarErro(e);
    }
  }

  void _mostrarErro(CameraException e) {
    if (!mounted) return;
    final negada = e.code.toLowerCase().contains('denied') ||
        e.code.toLowerCase().contains('permission');
    setState(() {
      _erro = negada
          ? 'Permissão de câmera negada.\n'
              'Clique no ícone de câmera/cadeado na barra de endereço '
              'do Chrome e permita o acesso.'
          : 'Não foi possível abrir a câmera.\n${e.description ?? e.code}';
    });
  }

  Future<void> _fotografar() async {
    final controller = _controller;
    if (controller == null || _fotografando) return;
    setState(() => _fotografando = true);
    try {
      var foto = await controller.takePicture();
      // Webcam/câmera frontal: o plugin salva espelhado; desfaz aqui
      // para o nome na caixa do remédio ficar legível.
      if (_cameras[_indice].lensDirection != CameraLensDirection.back) {
        final bytes = await desespelharFoto(await foto.readAsBytes());
        foto = XFile.fromData(bytes,
            mimeType: 'image/jpeg', name: 'comprovante.jpg');
      }
      if (mounted) Navigator.of(context).pop(foto);
    } on CameraException catch (e) {
      setState(() => _fotografando = false);
      _mostrarErro(e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    Widget corpo;
    if (_erro != null) {
      corpo = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  size: 64, color: Colors.white70),
              const SizedBox(height: 16),
              Text(_erro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );
    } else if (controller == null) {
      corpo = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ligando a câmera...',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    } else {
      corpo = Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // O tema define a cor do título; aqui ele precisa ser branco.
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        title: const Text('Fotografe a caixa ou o comprimido'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Trocar de câmera',
              onPressed: controller == null
                  ? null
                  : () => _abrir((_indice + 1) % _cameras.length),
              icon: const Icon(Icons.cameraswitch_outlined),
            ),
        ],
      ),
      body: SafeArea(child: corpo),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller == null
          ? null
          : FloatingActionButton.large(
              tooltip: 'Tirar foto',
              onPressed: _fotografando ? null : _fotografar,
              child: _fotografando
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.photo_camera),
            ),
    );
  }
}
