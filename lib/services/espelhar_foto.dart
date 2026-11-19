/// Desfaz o espelhamento das fotos tiradas pela webcam.
///
/// Importação condicional: no navegador usa o canvas do HTML
/// (`espelhar_foto_web.dart`); nas outras plataformas não faz nada.
library;

export 'espelhar_foto_stub.dart'
    if (dart.library.js_interop) 'espelhar_foto_web.dart';
