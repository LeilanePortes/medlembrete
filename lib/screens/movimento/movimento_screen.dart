import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/alerta_esquecido_service.dart';
import '../../services/detector_movimento.dart';
import '../../services/movimento_service.dart';
import '../../services/simulador_acelerometro.dart';
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
          final leitura = servico.ultima;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (servico.semSensor || servico.simulando) ...[
                _CartaoSimulacao(servico: servico),
                const SizedBox(height: 12),
              ],
              _CartaoEstado(servico: servico),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servico.simulando
                            ? 'Acelerômetro (m/s²) — simulado'
                            : 'Acelerômetro (m/s²)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
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
                      const Text(
                        'Últimos segundos',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      GraficoAcelerometro(leituras: servico.historico),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _CartaoAlerta(),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.vibration),
                  title: const Text('Movimentos bruscos detectados'),
                  subtitle: Text(
                    servico.simulando
                        ? 'Use o botão "Chacoalhar" da simulação'
                        : 'Chacoalhe o celular para testar',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${servico.movimentosBruscos}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
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

/// Modo simulação: usado quando o dispositivo não tem acelerômetro
/// (ex.: Chrome no computador). Os valores gerados passam pelo mesmo
/// detector de movimento das leituras reais.
class _CartaoSimulacao extends StatelessWidget {
  const _CartaoSimulacao({required this.servico});

  final MovimentoService servico;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.science_outlined),
              title: const Text('Modo simulação'),
              subtitle: Text(
                servico.semSensor
                    ? 'Este dispositivo não tem acelerômetro (ex.: Chrome no '
                          'computador). Os valores X, Y, Z são gerados pelo app.'
                    : 'Gera valores X, Y, Z artificiais para teste.',
              ),
              value: servico.simulando,
              onChanged: servico.definirSimulacao,
            ),
            if (servico.simulando)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<ModoSimulacao>(
                      segments: const [
                        ButtonSegment(
                          value: ModoSimulacao.mesa,
                          icon: Icon(Icons.table_restaurant_outlined),
                          label: Text('Na mesa'),
                        ),
                        ButtonSegment(
                          value: ModoSimulacao.andando,
                          icon: Icon(Icons.directions_walk),
                          label: Text('Andando'),
                        ),
                      ],
                      selected: {servico.simulador.modo},
                      onSelectionChanged: (s) =>
                          servico.definirModoSimulacao(s.first),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: servico.ativo ? servico.chacoalhar : null,
                      icon: const Icon(Icons.vibration),
                      label: const Text('Chacoalhar'),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
            child: Text(
              eixo,
              style: TextStyle(
                color: cor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
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

/// Configura a notificação de "celular esquecido" (desafio extra).
class _CartaoAlerta extends StatelessWidget {
  const _CartaoAlerta();

  String _rotulo(int segundos) =>
      segundos < 60 ? '$segundos s' : '${segundos ~/ 60} min';

  @override
  Widget build(BuildContext context) {
    final alerta = AlertaEsquecidoService.instance;
    return ListenableBuilder(
      listenable: alerta,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Avisar se o celular for esquecido'),
                subtitle: Text(
                  'Notifica quando ficar parado por ${_rotulo(alerta.segundos)}',
                ),
                value: alerta.ativo,
                onChanged: alerta.definirAtivo,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final s in AlertaEsquecidoService.opcoesSegundos)
                      ChoiceChip(
                        label: Text(_rotulo(s)),
                        selected: alerta.segundos == s,
                        onSelected: alerta.ativo
                            ? (_) => alerta.definirSegundos(s)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
