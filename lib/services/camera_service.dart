import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Captura fotos com a câmera do celular e as guarda na pasta do app.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  final ImagePicker _picker = ImagePicker();

  /// Abre a câmera traseira. Retorna null se o usuário cancelar.
  ///
  /// A foto é reduzida (máx. 1280 px, qualidade 80%) para economizar espaço.
  Future<XFile?> tirarFoto() {
    return _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
  }

  /// Alternativa para emuladores sem câmera configurada.
  Future<XFile?> escolherDaGaleria() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
  }

  /// Copia a foto (que fica em uma pasta temporária) para a pasta de
  /// documentos do app, onde ela não é apagada pelo sistema.
  Future<String> salvarComprovante(XFile foto) async {
    final documentos = await getApplicationDocumentsDirectory();
    final pasta = Directory('${documentos.path}/comprovantes');
    if (!await pasta.exists()) await pasta.create(recursive: true);

    final destino =
        '${pasta.path}/dose_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await foto.saveTo(destino);
    return destino;
  }
}
