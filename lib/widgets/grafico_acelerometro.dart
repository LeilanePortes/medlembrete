import 'package:flutter/material.dart';

import '../services/movimento_service.dart';

/// Cores usadas para cada eixo em toda a tela de movimento.
class CoresEixo {
  CoresEixo._();
  static const Color x = Color(0xFFE53935);
  static const Color y = Color(0xFF43A047);
  static const Color z = Color(0xFF1E88E5);
}

/// Gráfico de linhas simples (CustomPainter) com o histórico de X, Y e Z.
class GraficoAcelerometro extends StatelessWidget {
  const GraficoAcelerometro({super.key, required this.leituras});

  final List<LeituraAcelerometro> leituras;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: CustomPaint(
        painter: _GraficoPainter(
          leituras,
          corGrade: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _GraficoPainter extends CustomPainter {
  _GraficoPainter(this.leituras, {required this.corGrade});

  final List<LeituraAcelerometro> leituras;
  final Color corGrade;

  /// Escala vertical: de -20 a +20 m/s² (≈ ±2 g).
  static const double limite = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final grade = Paint()
      ..color = corGrade
      ..strokeWidth = 1;
    final meio = size.height / 2;
    canvas.drawLine(Offset(0, meio), Offset(size.width, meio), grade);
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grade);
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), grade);

    if (leituras.length < 2) return;
    final passo = size.width / (MovimentoService.tamanhoHistorico - 1);

    double yPara(double valor) {
      final v = valor.clamp(-limite, limite);
      return meio - (v / limite) * meio;
    }

    void linha(double Function(LeituraAcelerometro) eixo, Color cor) {
      final caminho = Path();
      for (var i = 0; i < leituras.length; i++) {
        final dx = i * passo;
        final dy = yPara(eixo(leituras[i]));
        i == 0 ? caminho.moveTo(dx, dy) : caminho.lineTo(dx, dy);
      }
      canvas.drawPath(
        caminho,
        Paint()
          ..color = cor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    linha((l) => l.x, CoresEixo.x);
    linha((l) => l.y, CoresEixo.y);
    linha((l) => l.z, CoresEixo.z);
  }

  @override
  bool shouldRepaint(covariant _GraficoPainter old) => true;
}
