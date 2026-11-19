import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../widgets/mapa_local.dart';

/// Mostra latitude/longitude atuais e se o usuário está em casa ou fora.
class LocalizacaoScreen extends StatefulWidget {
  const LocalizacaoScreen({super.key});

  @override
  State<LocalizacaoScreen> createState() => _LocalizacaoScreenState();
}

class _LocalizacaoScreenState extends State<LocalizacaoScreen> {
  final _servico = LocationService.instance;

  LeituraGps? _leitura;
  DateTime? _horaLeitura;
  bool _carregando = false;

  Future<void> _atualizar() async {
    setState(() => _carregando = true);
    final leitura = await _servico.obterPosicaoAtual();
    if (!mounted) return;
    setState(() {
      _leitura = leitura;
      _horaLeitura = DateTime.now();
      _carregando = false;
    });
  }

  Future<void> _definirCasa(Position p) async {
    await _servico.definirCasa(Coordenada(p.latitude, p.longitude));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Localização atual salva como "Casa" 🏠')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leitura = _leitura;

    return Scaffold(
      appBar: AppBar(title: const Text('Localização')),
      body: ListenableBuilder(
        listenable: _servico,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (leitura == null)
              _CartaoInfo(
                icone: Icons.my_location,
                titulo: 'Onde você está?',
                texto: 'Toque em "Obter localização" para ler o GPS. '
                    'Na primeira vez o app vai pedir permissão.',
              )
            else if (!leitura.sucesso)
              _CartaoErro(
                leitura: leitura,
                onConfigurar: () => _servico.abrirConfiguracoes(leitura.status),
              )
            else ...[
              _CartaoCoordenadas(
                posicao: leitura.posicao!,
                hora: _horaLeitura!,
              ),
              const SizedBox(height: 12),
              _CartaoCasa(
                posicao: leitura.posicao!,
                onDefinirCasa: () => _definirCasa(leitura.posicao!),
              ),
              const SizedBox(height: 12),
              // Desafio extra: mapa com a localização atual e o raio da casa.
              MapaLocal(
                latitude: leitura.posicao!.latitude,
                longitude: leitura.posicao!.longitude,
                casa: _servico.casa,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _carregando ? null : _atualizar,
              icon: _carregando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.gps_fixed),
              label: Text(_carregando
                  ? 'Lendo GPS...'
                  : (leitura == null
                      ? 'Obter localização'
                      : 'Atualizar localização')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoCoordenadas extends StatelessWidget {
  const _CartaoCoordenadas({required this.posicao, required this.hora});

  final Position posicao;
  final DateTime hora;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget valor(String rotulo, String texto) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 4),
              SelectableText(
                texto,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: scheme.primary),
                const SizedBox(width: 8),
                const Text('Coordenadas atuais',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                valor('Latitude', posicao.latitude.toStringAsFixed(6)),
                valor('Longitude', posicao.longitude.toStringAsFixed(6)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Precisão: ±${posicao.accuracy.round()} m  •  '
              'Lido às ${formatarHora(hora)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoCasa extends StatelessWidget {
  const _CartaoCasa({required this.posicao, required this.onDefinirCasa});

  final Position posicao;
  final VoidCallback onDefinirCasa;

  @override
  Widget build(BuildContext context) {
    final servico = LocationService.instance;
    final casa = servico.casa;

    if (casa == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.home_outlined),
                  SizedBox(width: 8),
                  Text('Casa não definida',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Salve sua casa para o app saber se você tomou o remédio '
                'em casa ou fora.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onDefinirCasa,
                icon: const Icon(Icons.add_home_outlined),
                label: const Text('Estou em casa agora'),
              ),
            ],
          ),
        ),
      );
    }

    final distancia =
        servico.distanciaAteCasa(posicao.latitude, posicao.longitude)!;
    final emCasa = LocationService.dentroDoRaio(distancia);
    final cor = emCasa ? AppTheme.sucesso : AppTheme.alerta;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cor.withValues(alpha: 0.15),
                  foregroundColor: cor,
                  child: Icon(emCasa ? Icons.home : Icons.directions_walk,
                      size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emCasa ? 'Você está em casa' : 'Você está fora de casa',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cor,
                        ),
                      ),
                      Text(
                        'Distância da casa: '
                        '${LocationService.formatarDistancia(distancia)} '
                        '(raio de ${LocationService.raioCasaMetros.round()} m)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Casa: $casa',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDefinirCasa,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Redefinir casa aqui'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoErro extends StatelessWidget {
  const _CartaoErro({required this.leitura, required this.onConfigurar});

  final LeituraGps leitura;
  final VoidCallback onConfigurar;

  @override
  Widget build(BuildContext context) {
    final podeConfigurar = leitura.status == StatusGps.servicoDesligado ||
        leitura.status == StatusGps.permissaoNegadaSempre;
    return Card(
      color: AppTheme.perigo.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_off, color: AppTheme.perigo),
                SizedBox(width: 8),
                Text('Não foi possível obter a localização',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(leitura.mensagem ?? ''),
            if (podeConfigurar) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onConfigurar,
                icon: const Icon(Icons.settings),
                label: const Text('Abrir configurações'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartaoInfo extends StatelessWidget {
  const _CartaoInfo({
    required this.icone,
    required this.titulo,
    required this.texto,
  });

  final IconData icone;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icone, size: 36),
        title: Text(titulo),
        subtitle: Text(texto),
      ),
    );
  }
}
