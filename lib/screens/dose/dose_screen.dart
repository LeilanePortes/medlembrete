import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/dose.dart';
import '../../models/medicamento.dart';
import '../../services/camera_service.dart';
import '../../services/detector_movimento.dart';
import '../../services/dose_repository.dart';
import '../../services/location_service.dart';
import '../../services/medicamento_repository.dart';
import '../../services/movimento_service.dart';

/// Abre a comprovação de dose: se houver mais de um remédio,
/// pergunta qual está sendo tomado.
Future<void> abrirComprovacao(BuildContext context) async {
  final lista = MedicamentoRepository.instance.medicamentos;
  if (lista.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cadastre um remédio primeiro.')),
    );
    return;
  }

  final escolhido = lista.length == 1
      ? lista.first
      : await showModalBottomSheet<Medicamento>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Qual remédio você vai tomar?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                for (final m in lista)
                  ListTile(
                    leading: const Icon(Icons.medication),
                    title: Text(m.nome),
                    subtitle: Text(m.dosagem),
                    trailing: Text(m.horario),
                    onTap: () => Navigator.pop(context, m),
                  ),
              ],
            ),
          ),
        );

  if (escolhido == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => DoseScreen(medicamento: escolhido)),
  );
}

/// Tela "Hora do remédio": o usuário fotografa a caixa ou o comprimido
/// para comprovar que tomou a dose.
///
/// Integração dos recursos: junto com a foto, o comprovante guarda a
/// localização (em casa ou fora) e o estado do celular (acelerômetro).
class DoseScreen extends StatefulWidget {
  const DoseScreen({super.key, required this.medicamento});

  final Medicamento medicamento;

  @override
  State<DoseScreen> createState() => _DoseScreenState();
}

class _DoseScreenState extends State<DoseScreen> {
  XFile? _foto;
  Uint8List? _previa; // bytes da foto para exibir (celular e web)
  bool _salvando = false;

  LeituraGps? _gps;
  bool _lendoGps = false;

  @override
  void initState() {
    super.initState();
    // Lê o GPS em paralelo enquanto o usuário tira a foto.
    _lerGps();
  }

  Future<void> _lerGps() async {
    setState(() => _lendoGps = true);
    final leitura = await LocationService.instance.obterPosicaoAtual();
    if (!mounted) return;
    setState(() {
      _gps = leitura;
      _lendoGps = false;
    });
  }

  Future<void> _capturar({bool galeria = false}) async {
    try {
      final camera = CameraService.instance;
      final foto = galeria
          ? await camera.escolherDaGaleria()
          : await camera.tirarFoto(context);
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = foto;
        _previa = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a câmera: $e')),
      );
    }
  }

  Future<void> _confirmar() async {
    final foto = _foto;
    if (foto == null) return;
    setState(() => _salvando = true);

    final m = widget.medicamento;
    final agora = DateTime.now();
    final posicao = _gps?.sucesso == true ? _gps!.posicao : null;
    final local = LocationService.instance;
    final movimento = MovimentoService.instance;

    try {
      final caminho = await CameraService.instance.salvarComprovante(foto);
      await DoseRepository.instance.registrar(
        Dose(
          id: agora.millisecondsSinceEpoch,
          medicamentoId: m.id,
          nomeMedicamento: m.nome,
          dosagem: m.dosagem,
          horarioPrevisto: m.horario,
          dataHora: agora,
          fotoPath: caminho,
          latitude: posicao?.latitude,
          longitude: posicao?.longitude,
          emCasa: posicao == null
              ? null
              : local.estaEmCasa(posicao.latitude, posicao.longitude),
          distanciaCasaMetros: posicao == null
              ? null
              : local.distanciaAteCasa(posicao.latitude, posicao.longitude),
          estadoCelular: movimento.ativo ? movimento.estado : null,
        ),
      );
    } catch (e) {
      // Ex.: armazenamento do navegador cheio (limite de ~5 MB).
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar o comprovante. '
            '${kIsWeb ? 'Exclua comprovantes antigos no Histórico. ' : ''}($e)',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.sucesso,
        content: Text('Dose de ${m.nome} comprovada! ✅'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = widget.medicamento;
    final foto = _previa;

    return Scaffold(
      appBar: AppBar(title: const Text('Hora do remédio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabeçalho com o remédio
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.medication,
                  size: 48,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.nome,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '${m.dosagem.isEmpty ? 'Dose' : m.dosagem} • ${m.horario}',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Área da foto
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: foto == null
                  ? InkWell(
                      onTap: _capturar,
                      child: Container(
                        color: scheme.surfaceContainerHighest,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 64,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 12),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Fotografe a caixa ou o comprimido\n'
                                'para comprovar que tomou',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image.memory(foto, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          _PainelContexto(gps: _gps, lendoGps: _lendoGps, onTentar: _lerGps),
          const SizedBox(height: 16),

          if (foto == null) ...[
            FilledButton.icon(
              onPressed: _capturar,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Tirar foto'),
            ),
            TextButton(
              onPressed: () => _capturar(galeria: true),
              child: Text(
                kIsWeb
                    ? 'Sem webcam? Escolher um arquivo de imagem'
                    : 'Sem câmera? Escolher da galeria',
              ),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _salvando ? null : _confirmar,
              icon: _salvando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Confirmar que tomei'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _salvando ? null : _capturar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tirar outra foto'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mostra, ao vivo, o que vai ser registrado junto com a foto:
/// localização (GPS) e estado do celular (acelerômetro).
class _PainelContexto extends StatelessWidget {
  const _PainelContexto({
    required this.gps,
    required this.lendoGps,
    required this.onTentar,
  });

  final LeituraGps? gps;
  final bool lendoGps;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final local = LocationService.instance;

    Widget gpsInfo;
    if (lendoGps) {
      gpsInfo = const ListTile(
        leading: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Obtendo localização...'),
      );
    } else if (gps?.sucesso == true) {
      final p = gps!.posicao!;
      final emCasa = local.estaEmCasa(p.latitude, p.longitude);
      gpsInfo = ListTile(
        leading: Icon(
          emCasa == true ? Icons.home : Icons.location_on,
          color: emCasa == true ? AppTheme.sucesso : AppTheme.alerta,
        ),
        title: Text(switch (emCasa) {
          true => 'Em casa',
          false => 'Fora de casa',
          null => 'Localização obtida (casa não definida)',
        }),
        subtitle: Text(
          '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}',
        ),
      );
    } else {
      gpsInfo = ListTile(
        leading: const Icon(Icons.location_off, color: AppTheme.perigo),
        title: const Text('Sem localização'),
        subtitle: Text(gps?.mensagem ?? ''),
        trailing: IconButton(
          tooltip: 'Tentar de novo',
          onPressed: onTentar,
          icon: const Icon(Icons.refresh),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          gpsInfo,
          Divider(height: 1, color: scheme.outlineVariant),
          ListenableBuilder(
            listenable: MovimentoService.instance,
            builder: (context, _) {
              final movimento = MovimentoService.instance;
              final estado = movimento.estado;
              return ListTile(
                leading: Icon(
                  estado == EstadoMovimento.emMovimento
                      ? Icons.directions_walk
                      : Icons.phone_android,
                  color: scheme.primary,
                ),
                title: Text(
                  movimento.ativo
                      ? 'Celular: ${estado.rotulo.toLowerCase()}'
                      : 'Acelerômetro pausado',
                ),
                subtitle: const Text('Registrado pelo acelerômetro'),
              );
            },
          ),
        ],
      ),
    );
  }
}
