import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../localizacao/localizacao_screen.dart';
import '../medicamentos/medicamentos_screen.dart';
import '../movimento/movimento_screen.dart';

/// Estrutura principal: barra de navegação inferior com as abas do app.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _indice = 0;

  void _irPara(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    final telas = <Widget>[
      HomeScreen(onNavegar: _irPara),
      const MedicamentosScreen(),
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
