import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/detector_movimento.dart';
import '../../services/movimento_service.dart';
import '../../widgets/grafico_acelerometro.dart';

/// Valores X, Y e Z do acelerômetro em tempo real e o estado do celular.
class MovimentoScreen extends StatelessWidget {
  const MovimentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servico = MovimentoService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimento'),
        actions: [
          ListenableBuilder(
            listenable: servico,
            builder: (context, _) => IconButton(
              tooltip: servico.ativo ? 'Pausar leitura' : 'Retomar leitura',
              icon: Icon(servico.ativo ? Icons.pause : Icons.play_arrow),
              onPressed: servico.ativo ? servico.parar : servico.iniciar,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: servico,
        builder: (context, _) {
          if (servico.erro != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(servico.erro!, textAlign: TextAlign.center),
              ),
            );
          }
          final leitura = servico.ultima;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CartaoEstado(servico: servico),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Acelerômetro (m/s²)',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      _LinhaEixo('X', leitura?.x, CoresEixo.x),
                      _LinhaEixo('Y', leitura?.y, CoresEixo.y),
                      _LinhaEixo('Z', leitura?.z, CoresEixo.z),
                      const Divider(height: 24),
                      Text(
                        'Magnitude: ${servico.detector.magnitude.toStringAsFixed(2)} m/s²'
                        '   •   Variação: ${servico.detector.desvio.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Últimos segundos',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      GraficoAcelerometro(leituras: servico.historico),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.vibration),
                  title: const Text('Movimentos bruscos detectados'),
                  subtitle: const Text('Chacoalhe o celular para testar'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${servico.movimentosBruscos}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Zerar',
                        onPressed: servico.zerarContador,
                        icon: const Icon(Icons.restart_alt),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartaoEstado extends StatelessWidget {
  const _CartaoEstado({required this.servico});

  final MovimentoService servico;

  @override
  Widget build(BuildContext context) {
    final (icone, cor, dica) = switch (servico.estado) {
      EstadoMovimento.emMovimento => (
          Icons.directions_walk,
          AppTheme.sucesso,
          'O celular está sendo usado ou carregado.',
        ),
      EstadoMovimento.parado => (
          Icons.phone_android,
          AppTheme.alerta,
          'Parado há ${servico.tempoParado.inSeconds} s.',
        ),
      EstadoMovimento.esquecido => (
          Icons.phonelink_erase,
          AppTheme.perigo,
          'Parado há ${servico.tempoParado.inSeconds} s — '
              'o celular pode ter sido esquecido!',
        ),
    };

    return Card(
      color: cor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cor,
              foregroundColor: Colors.white,
              child: Icon(icone, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servico.ativo ? servico.estado.rotulo : 'Leitura pausada',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cor,
                    ),
                  ),
                  Text(dica),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaEixo extends StatelessWidget {
  const _LinhaEixo(this.eixo, this.valor, this.cor);

  final String eixo;
  final double? valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final v = valor ?? 0;
    // Barra de 0 a 1 representando -20..+20 m/s².
    final proporcao = ((v + 20) / 40).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(eixo,
                style: TextStyle(
                    color: cor, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            width: 92,
            child: Text(
              valor == null ? '--' : v.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: proporcao,
                minHeight: 10,
                color: cor,
                backgroundColor: cor.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
