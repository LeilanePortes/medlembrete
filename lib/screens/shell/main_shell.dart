import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/medicamento_repository.dart';
import '../../services/notification_service.dart';
import '../dose/dose_screen.dart';
import '../historico/historico_screen.dart';
import '../home/home_screen.dart';
import '../localizacao/localizacao_screen.dart';
import '../medicamentos/medicamentos_screen.dart';
import '../movimento/movimento_screen.dart';

/// Estrutura principal: barra de navegação inferior com as abas do app.
///
/// Também é responsável por reagir ao toque nas notificações,
/// abrindo a tela "Hora do remédio".
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _indice = 0;
  StreamSubscription<String?>? _toques;

  @override
  void initState() {
    super.initState();
    final notificacoes = NotificationService.instance;
    _toques = notificacoes.toques.listen(_abrirPeloPayload);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kIsWeb) {
        // No navegador a permissão só pode ser pedida após um clique:
        // mostra um aviso com o botão "Permitir".
        _mostrarAvisoPermissaoWeb();
      } else {
        // Pede a permissão de notificação logo na primeira abertura.
        await notificacoes.solicitarPermissoes();
      }
      // Se o app foi aberto pela notificação, vai direto para a dose.
      final payload = notificacoes.payloadDeAbertura;
      notificacoes.payloadDeAbertura = null;
      _abrirPeloPayload(payload);
    });
  }

  @override
  void dispose() {
    _toques?.cancel();
    super.dispose();
  }

  void _mostrarAvisoPermissaoWeb() {
    final notificacoes = NotificationService.instance;
    if (!mounted || !notificacoes.precisaPermissaoWeb) return;
    final mensageiro = ScaffoldMessenger.of(context);
    final bloqueada = notificacoes.bloqueadaNaWeb;
    mensageiro.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.notifications_active_outlined),
        content: Text(bloqueada
            ? 'As notificações estão bloqueadas neste navegador. Clique no '
                'cadeado ao lado do endereço do site e permita "Notificações".'
            : 'Permita as notificações para receber o aviso '
                'na hora de cada remédio.'),
        actions: [
          TextButton(
            onPressed: mensageiro.hideCurrentMaterialBanner,
            child: const Text('Agora não'),
          ),
          if (!bloqueada)
            FilledButton(
              onPressed: () async {
                mensageiro.hideCurrentMaterialBanner();
                await notificacoes.solicitarPermissoes();
              },
              child: const Text('Permitir'),
            ),
        ],
      ),
    );
  }

  void _abrirPeloPayload(String? payload) {
    // Aviso de estoque baixo: abre a lista de remédios (botão "Repor").
    if (NotificationService.idEstoqueDoPayload(payload) != null) {
      if (mounted) _irPara(1);
      return;
    }
    final id = NotificationService.idDoPayload(payload);
    if (id == null || !mounted) return;
    final medicamento = MedicamentoRepository.instance.porId(id);
    if (medicamento == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoseScreen(medicamento: medicamento),
      ),
    );
  }

  void _irPara(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    final telas = <Widget>[
      HomeScreen(onNavegar: _irPara),
      const MedicamentosScreen(),
      const HistoricoScreen(),
      const LocalizacaoScreen(),
      const MovimentoScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _indice, children: telas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _irPara,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Remédios',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Local',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Movimento',
          ),
        ],
      ),
    );
  }
}
