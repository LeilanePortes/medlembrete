import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/dose/webcam_screen.dart';

/// Captura a foto de comprovação e a guarda no armazenamento do app.
///
/// - Celular: abre a câmera nativa (image_picker) e salva o arquivo
///   na pasta de documentos do app.
/// - Navegador (Chrome): abre a webcam dentro do app (pacote camera) e
///   guarda a foto como texto base64 (data URL) no armazenamento local
///   do navegador, porque na web não existe sistema de arquivos.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  final ImagePicker _picker = ImagePicker();

  /// Prefixo das fotos guardadas no navegador.
  static const String prefixoDataUrl = 'data:image/';

  /// Abre a câmera. Retorna null se o usuário cancelar.
  ///
  /// A foto é reduzida (máx. 1280 px, qualidade 80%) para economizar espaço.
  Future<XFile?> tirarFoto(BuildContext context) {
    if (kIsWeb) {
      return Navigator.of(context)
          .push<XFile>(MaterialPageRoute(builder: (_) => const WebcamScreen()));
    }
    return _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
  }

  /// Alternativa quando não há câmera (emulador, PC sem webcam):
  /// escolhe uma imagem da galeria ou, no navegador, um arquivo.
  Future<XFile?> escolherDaGaleria() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      // No navegador a foto fica guardada como texto: menor é melhor.
      maxWidth: kIsWeb ? 800 : 1280,
      maxHeight: kIsWeb ? 800 : 1280,
      imageQuality: kIsWeb ? 70 : 80,
    );
  }

  /// Guarda a foto de forma permanente e devolve a referência
  /// que vai para o histórico (caminho do arquivo ou data URL).
  Future<String> salvarComprovante(XFile foto) async {
    if (kIsWeb) {
      return paraDataUrl(await foto.readAsBytes(), foto.mimeType);
    }

    // Copia a foto (que fica em uma pasta temporária) para a pasta de
    // documentos do app, onde ela não é apagada pelo sistema.
    final documentos = await getApplicationDocumentsDirectory();
    final pasta = Directory('${documentos.path}/comprovantes');
    if (!await pasta.exists()) await pasta.create(recursive: true);

    final destino =
        '${pasta.path}/dose_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await foto.saveTo(destino);
    return destino;
  }

  /// Apaga a foto de um comprovante excluído.
  Future<void> apagarComprovante(String referencia) async {
    // No navegador a foto está dentro do próprio registro da dose.
    if (kIsWeb || ehDataUrl(referencia)) return;
    final arquivo = File(referencia);
    if (await arquivo.exists()) await arquivo.delete();
  }

  static bool ehDataUrl(String referencia) =>
      referencia.startsWith(prefixoDataUrl);

  /// Converte os bytes da imagem em `data:image/jpeg;base64,...`.
  static String paraDataUrl(Uint8List bytes, [String? mimeType]) =>
      'data:${mimeType ?? 'image/jpeg'};base64,${base64Encode(bytes)}';

  /// Faz o caminho inverso de [paraDataUrl].
  static Uint8List bytesDoDataUrl(String dataUrl) =>
      UriData.parse(dataUrl).contentAsBytes();
}
