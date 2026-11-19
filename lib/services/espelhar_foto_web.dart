import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// O plugin da câmera (web) salva as fotos da webcam/câmera frontal
/// espelhadas, como uma selfie — o texto da caixa do remédio ficaria
/// ao contrário. Aqui a imagem é desenhada invertida num canvas para
/// voltar ao normal e salva de novo como JPEG (qualidade 85%).
Future<Uint8List> desespelharFoto(Uint8List jpeg) async {
  final blob = web.Blob(
    [jpeg.toJS].toJS,
    web.BlobPropertyBag(type: 'image/jpeg'),
  );
  final url = web.URL.createObjectURL(blob);
  try {
    final imagem = web.HTMLImageElement()..src = url;
    await imagem.decode().toDart;

    final largura = imagem.naturalWidth;
    final canvas = web.HTMLCanvasElement()
      ..width = largura
      ..height = imagem.naturalHeight;
    canvas.context2D
      ..translate(largura.toDouble(), 0)
      ..scale(-1, 1)
      ..drawImage(imagem, 0, 0);

    final pronto = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) => pronto.complete(b)).toJS,
      'image/jpeg',
      0.85.toJS,
    );
    final resultado = await pronto.future;
    if (resultado == null) return jpeg;
    final buffer = await resultado.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
